#ifndef DICOM_PARSER_H
#define DICOM_PARSER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Structure containing the result of parsing a DICOM file.
 * The json_data field contains a JSON string with all DICOM attributes.
 * The error_message field contains any error that occurred during parsing.
 * Both fields are heap-allocated and must be freed using free_dicom_parse_result.
 */
typedef struct {
    char* json_data;      // JSON string containing DICOM attributes
    char* error_message;  // Error message if parsing failed, NULL otherwise
} DicomParseResult;

/**
 * Parse a DICOM file and return its contents as a JSON string.
 * 
 * @param path Path to the DICOM file to parse
 * @return DicomParseResult containing either the JSON data or an error message
 */
DicomParseResult parse_dicom_file(const char* path);

/**
 * Free memory allocated for a DicomParseResult.
 * Must be called to avoid memory leaks.
 * 
 * @param result The DicomParseResult to free
 */
void free_dicom_parse_result(DicomParseResult result);

#ifdef __cplusplus
}
#endif

#endif /* DICOM_PARSER_H */