use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use dicom::core::dictionary::{DataDictionary, DataDictionaryEntry};
use dicom::core::{DicomValue, Tag, VR};
use dicom::object::open_file;
use dicom_dictionary_std::StandardDataDictionary;
use dicom_pixeldata::{ConvertOptions, PixelDecoder, VoiLutOption};
use image::codecs::jpeg::JpegEncoder;
use image::ColorType;
use serde::{Deserialize, Serialize};
use std::ffi::{CStr, CString};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::os::raw::c_char;
use std::ptr;

#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "content")]
enum AttributeValue {
    String(String),
    Sequence(Vec<DicomAttribute>),
}

#[derive(Serialize, Deserialize)]
struct DicomAttribute {
    depth: i32,
    tag: String,
    name: String,
    vr: String,
    value: AttributeValue,
}

#[derive(Serialize, Deserialize)]
struct Dimensions {
    rows: i32,
    columns: i32,
}

#[derive(Serialize, Deserialize)]
struct DicomDebugInfo {
    // File information
    file_size: u64,
    file_preamble: String,
    dicom_magic: String,
    transfer_syntax: Option<String>,

    // General DICOM info
    attribute_count: usize,
    sequence_count: usize,
    meta_info_present: bool,

    // Pixel data info
    has_pixel_data: bool,
    pixel_data_vr: Option<String>,
    image_dimensions: Option<Dimensions>,
    number_of_frames: Option<i32>,
    bits_allocated: Option<i32>,
    samples_per_pixel: Option<i32>,
    photometric_interpretation: Option<String>,
    pixel_representation: Option<i32>,

    // Error tracking
    parse_error: Option<String>,
    pixel_decode_error: Option<String>,
    pixel_convert_error: Option<String>,
    pixel_encode_error: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct DicomParseOutput {
    attributes: Vec<DicomAttribute>,
    preview_images: Option<Vec<String>>,
    debug_info: DicomDebugInfo,
}

#[repr(C)]
pub struct DicomParseResult {
    json_data: *mut c_char,
    error_message: *mut c_char,
}

fn analyze_file_structure(file: &mut File) -> (DicomDebugInfo, String) {
    let mut debug_info = DicomDebugInfo {
        file_size: 0,
        file_preamble: String::new(),
        dicom_magic: String::new(),
        transfer_syntax: None,
        attribute_count: 0,
        sequence_count: 0,
        meta_info_present: false,
        has_pixel_data: false,
        pixel_data_vr: None,
        image_dimensions: None,
        number_of_frames: None,
        bits_allocated: None,
        samples_per_pixel: None,
        photometric_interpretation: None,
        pixel_representation: None,
        parse_error: None,
        pixel_decode_error: None,
        pixel_convert_error: None,
        pixel_encode_error: None,
    };

    let mut analysis = String::new();

    // Get file size
    if let Ok(size) = file.seek(SeekFrom::End(0)) {
        debug_info.file_size = size;
        analysis.push_str(&format!("File size: {} bytes\n", size));
        // Reset position
        let _ = file.seek(SeekFrom::Start(0));
    }

    // Read first 256 bytes for analysis
    let mut header = vec![0u8; 256];
    if file.read_exact(&mut header).is_ok() {
        // Check for DICOM magic number
        if header.len() >= 132 {
            debug_info.file_preamble = format!("{:02X?}", &header[0..128]);
            debug_info.dicom_magic = String::from_utf8_lossy(&header[128..132]).into_owned();

            analysis.push_str(&String::from("Header analysis:\n"));
            analysis.push_str(&format!(
                "First 128 bytes (preamble): {}\n",
                debug_info.file_preamble
            ));
            analysis.push_str(&format!("DICM marker at 128: {}\n", debug_info.dicom_magic));

            // Try to identify transfer syntax
            if header.len() >= 256 {
                analysis.push_str(&String::from("Looking for transfer syntax UID...\n"));
                // Common transfer syntax positions and patterns
                if let Some(pos) = header[132..].windows(2).position(|w| w == b"1.") {
                    let uid = String::from_utf8_lossy(
                        &header[pos + 132..std::cmp::min(pos + 132 + 64, header.len())],
                    )
                    .into_owned();
                    debug_info.transfer_syntax = Some(uid.clone());
                    analysis.push_str(&format!(
                        "Possible UID found at offset {}: {}\n",
                        pos + 132,
                        uid
                    ));
                }
            }
        }
    }

    (debug_info, analysis)
}

fn get_tag_name(tag: Tag) -> String {
    let dict = StandardDataDictionary;
    match dict.by_tag(tag) {
        Some(entry) => entry.alias().to_string(),
        None => "Unknown".to_string(),
    }
}

fn format_tag_id(tag: Tag) -> String {
    format!("({:04X},{:04X})", tag.group(), tag.element())
}

fn update_debug_info_from_dicom(
    obj: &dicom::object::FileDicomObject<dicom::object::InMemDicomObject>,
    debug_info: &mut DicomDebugInfo,
) {
    // Count sequences
    debug_info.sequence_count = obj
        .tags()
        .filter(|tag| {
            if let Ok(element) = obj.element(*tag) {
                element.vr() == VR::SQ
            } else {
                false
            }
        })
        .count();

    // Check for meta information
    debug_info.meta_info_present = obj.tags().any(|tag| tag.group() == 0x0002);

    // Count total attributes
    debug_info.attribute_count = obj.tags().count();

    // Check for pixel data
    if let Ok(element) = obj.element(Tag(0x7FE0, 0x0010)) {
        debug_info.has_pixel_data = true;
        debug_info.pixel_data_vr = Some(element.vr().to_string().into());
    }

    // Get image attributes
    if let (Ok(rows), Ok(columns)) = (
        obj.element(Tag(0x0028, 0x0010)),
        obj.element(Tag(0x0028, 0x0011)),
    ) {
        if let (Ok(r), Ok(c)) = (rows.to_int(), columns.to_int()) {
            debug_info.image_dimensions = Some(Dimensions {
                rows: r,
                columns: c,
            });
        }
    }

    if let Ok(bits) = obj.element(Tag(0x0028, 0x0100)) {
        debug_info.bits_allocated = bits.to_int().ok();
    }
    if let Ok(samples) = obj.element(Tag(0x0028, 0x0002)) {
        debug_info.samples_per_pixel = samples.to_int().ok();
    }
    if let Ok(photo_interp) = obj.element(Tag(0x0028, 0x0004)) {
        debug_info.photometric_interpretation = photo_interp.to_str().ok().map(|s| s.to_string());
    }
    if let Ok(pixel_rep) = obj.element(Tag(0x0028, 0x0103)) {
        debug_info.pixel_representation = pixel_rep.to_int().ok();
    }

    // Get number of frames
    if let Ok(frames) = obj.element(Tag(0x0028, 0x0008)) {
        debug_info.number_of_frames = frames.to_int().ok();
    }
}

fn generate_preview_image(
    obj: &dicom::object::FileDicomObject<dicom::object::InMemDicomObject>,
    debug_info: &mut DicomDebugInfo,
) -> Option<Vec<String>> {
    match obj.decode_pixel_data() {
        Ok(pixel_data) => {
            let options = ConvertOptions::new()
                .with_voi_lut(VoiLutOption::Normalize)
                .force_8bit();

            let num_frames = debug_info.number_of_frames.unwrap_or(1);
            let mut frame_images = Vec::with_capacity(num_frames as usize);

            for frame_index in 0..num_frames {
                match pixel_data.to_dynamic_image_with_options(frame_index as u32, &options) {
                    Ok(image) => {
                        let mut jpeg_data = Vec::new();
                        let mut encoder = JpegEncoder::new_with_quality(&mut jpeg_data, 60);

                        // Convert to appropriate format and encode
                        let (raw_data, width, height, color_type) =
                            if debug_info.photometric_interpretation.as_deref()
                                == Some("MONOCHROME2")
                                && debug_info.samples_per_pixel == Some(1)
                            {
                                let luma = image.to_luma8();
                                (
                                    luma.as_raw().to_vec(),
                                    luma.width(),
                                    luma.height(),
                                    ColorType::L8.into(),
                                )
                            } else {
                                let rgb = image.to_rgb8();
                                (
                                    rgb.as_raw().to_vec(),
                                    rgb.width(),
                                    rgb.height(),
                                    ColorType::Rgb8.into(),
                                )
                            };

                        match encoder.encode(&raw_data, width, height, color_type) {
                            Ok(_) => frame_images.push(BASE64.encode(&jpeg_data)),
                            Err(e) => {
                                debug_info.pixel_encode_error = Some(format!(
                                    "JPEG encoding error for frame {}: {:?}",
                                    frame_index, e
                                ));
                                return None;
                            }
                        }
                    }
                    Err(e) => {
                        debug_info.pixel_convert_error = Some(format!(
                            "Image conversion error for frame {}: {:?}",
                            frame_index, e
                        ));
                        return None;
                    }
                }
            }

            if frame_images.is_empty() {
                None
            } else {
                Some(frame_images)
            }
        }
        Err(e) => {
            debug_info.pixel_decode_error = Some(format!("Pixel data decode error: {:?}", e));
            None
        }
    }
}

fn parse_dicom_element(
    obj: &dicom::object::FileDicomObject<dicom::object::InMemDicomObject>,
    attributes: &mut Vec<DicomAttribute>,
) {
    let current_depth = 0;

    // Process each element in the DICOM object
    for tag in obj.tags() {
        if let Ok(element) = obj.element(tag) {
            // Skip PixelData attribute since we handle it separately
            if tag == Tag(0x7FE0, 0x0010) {
                attributes.push(DicomAttribute {
                    depth: current_depth,
                    tag: format_tag_id(tag),
                    name: get_tag_name(tag),
                    vr: element.vr().to_string().into(),
                    value: AttributeValue::String("[PixelData]".to_string()),
                });
                continue;
            }

            // Process element and add to attributes
            process_dicom_element(element, tag, current_depth, attributes);
        }
    }
}

fn process_dicom_element(
    element: &dicom::object::mem::InMemElement,
    tag: Tag,
    depth: i32,
    attributes: &mut Vec<DicomAttribute>,
) {
    if element.vr() == VR::SQ {
        // Handle sequence
        let mut sequence_items = Vec::new();

        if let DicomValue::Sequence(items) = element.value() {
            // Process each item in the sequence
            for item in items.items() {
                // Process each element in the item
                for item_tag in item.tags() {
                    if let Ok(item_element) = item.element(item_tag) {
                        process_sequence_item(
                            item_element,
                            item_tag,
                            depth + 1,
                            &mut sequence_items,
                        );
                    }
                }
            }
        }

        attributes.push(DicomAttribute {
            depth,
            tag: format_tag_id(tag),
            name: get_tag_name(tag),
            vr: element.vr().to_string().into(),
            value: AttributeValue::Sequence(sequence_items),
        });
    } else {
        // Handle non-sequence elements
        let value = if element.vr() == VR::OB || element.vr() == VR::OW || element.vr() == VR::UN {
            AttributeValue::String("[Binary data]".to_string())
        } else if let Ok(s) = element.to_str() {
            AttributeValue::String(s.to_string())
        } else {
            AttributeValue::String(format!("[Cannot display value of type {}]", element.vr()))
        };

        attributes.push(DicomAttribute {
            depth,
            tag: format_tag_id(tag),
            name: get_tag_name(tag),
            vr: element.vr().to_string().into(),
            value,
        });
    }
}

fn process_sequence_item(
    element: &dicom::object::mem::InMemElement,
    tag: Tag,
    depth: i32,
    attributes: &mut Vec<DicomAttribute>,
) {
    if element.vr() == VR::SQ {
        // Handle nested sequence
        let mut nested_items = Vec::new();

        if let DicomValue::Sequence(items) = element.value() {
            // Process each item in the nested sequence
            for item in items.items() {
                for nested_tag in item.tags() {
                    if let Ok(nested_element) = item.element(nested_tag) {
                        let value = if let Ok(s) = nested_element.to_str() {
                            AttributeValue::String(s.to_string())
                        } else {
                            AttributeValue::String(format!(
                                "[Cannot display value of type {}]",
                                nested_element.vr()
                            ))
                        };

                        nested_items.push(DicomAttribute {
                            depth: depth + 1,
                            tag: format_tag_id(nested_tag),
                            name: get_tag_name(nested_tag),
                            vr: nested_element.vr().to_string().into(),
                            value,
                        });
                    }
                }
            }
        }

        attributes.push(DicomAttribute {
            depth,
            tag: format_tag_id(tag),
            name: get_tag_name(tag),
            vr: element.vr().to_string().into(),
            value: AttributeValue::Sequence(nested_items),
        });
    } else {
        // Handle non-sequence elements
        let value = if element.vr() == VR::OB || element.vr() == VR::OW || element.vr() == VR::UN {
            AttributeValue::String("[Binary data]".to_string())
        } else if let Ok(s) = element.to_str() {
            AttributeValue::String(s.to_string())
        } else {
            AttributeValue::String(format!("[Cannot display value of type {}]", element.vr()))
        };

        attributes.push(DicomAttribute {
            depth,
            tag: format_tag_id(tag),
            name: get_tag_name(tag),
            vr: element.vr().to_string().into(),
            value,
        });
    }
}

/// Parses a DICOM file and returns a JSON representation of its contents
/// along with preview images.
///
/// # Arguments
///
/// * `path` - C string pointer to the path of the DICOM file to parse
///
/// # Safety
///
/// This function is unsafe because it dereferences the raw pointer `path`.
/// The caller must ensure that:
/// - `path` is a valid pointer to a null-terminated C string
/// - The memory referenced by `path` remains valid for the duration of this function call
/// - The C string pointed to by `path` is valid UTF-8
#[no_mangle]
pub unsafe extern "C" fn parse_dicom_file(path: *const c_char) -> DicomParseResult {
    let mut result = DicomParseResult {
        json_data: ptr::null_mut(),
        error_message: ptr::null_mut(),
    };

    if path.is_null() {
        result.error_message = CString::new("Path is null").unwrap().into_raw();
        return result;
    }

    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(e) => {
                result.error_message = CString::new(format!("Invalid UTF-8 in path: {}", e))
                    .unwrap()
                    .into_raw();
                return result;
            }
        }
    };

    // Check if file exists and is readable
    if !std::path::Path::new(path_str).exists() {
        result.error_message = CString::new(format!("File does not exist: {}", path_str))
            .unwrap()
            .into_raw();
        return result;
    }

    // Try to read and analyze the file structure
    let mut file = match File::open(path_str) {
        Ok(f) => f,
        Err(e) => {
            result.error_message =
                CString::new(format!("Cannot open file: {}. Error: {}", path_str, e))
                    .unwrap()
                    .into_raw();
            return result;
        }
    };

    let (mut debug_info, file_analysis) = analyze_file_structure(&mut file);

    // Reopen file for DICOM parsing
    match open_file(path_str) {
        Ok(obj) => {
            let mut attributes = Vec::new();

            // Update debug info with DICOM object information
            update_debug_info_from_dicom(&obj, &mut debug_info);

            // Process all elements
            parse_dicom_element(&obj, &mut attributes);

            // Generate preview image
            let preview_image = generate_preview_image(&obj, &mut debug_info);

            // Create output structure
            let output = DicomParseOutput {
                attributes,
                preview_images: preview_image,
                debug_info,
            };

            // Serialize to JSON using serde_json
            match serde_json::to_string(&output) {
                Ok(json_string) => {
                    result.json_data = CString::new(json_string).unwrap().into_raw();
                }
                Err(e) => {
                    result.error_message =
                        CString::new(format!("Failed to serialize to JSON: {}", e))
                            .unwrap()
                            .into_raw();
                }
            }
        }
        Err(e) => {
            debug_info.parse_error = Some(format!("Failed to parse DICOM file: {:?}", e));
            let error_msg = format!(
                "Failed to parse DICOM file: {}.\nError details: {:?}\n\n\
                File Analysis:\n{}\n\
                This could be because:\n\
                1. The file is not a valid DICOM file\n\
                2. The file is corrupted\n\
                3. The file uses an unsupported transfer syntax\n\
                4. There are insufficient read permissions",
                path_str, e, file_analysis
            );
            result.error_message = CString::new(error_msg).unwrap().into_raw();
        }
    }

    result
}

#[no_mangle]
pub extern "C" fn free_dicom_parse_result(result: DicomParseResult) {
    unsafe {
        if !result.json_data.is_null() {
            let _ = CString::from_raw(result.json_data);
        }
        if !result.error_message.is_null() {
            let _ = CString::from_raw(result.error_message);
        }
    }
}
