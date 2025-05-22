function toggleSequence(button) {
    const content = button.nextElementSibling;
    const isExpanded = content.style.display !== 'none';
    content.style.display = isExpanded ? 'none' : 'block';
    button.textContent = button.textContent.replace(
        isExpanded ? '▼' : '▶',
        isExpanded ? '▶' : '▼'
    );
}

function expandAll() {
    document.querySelectorAll('.sequence-content').forEach(content => {
        content.style.display = 'block';
    });
    document.querySelectorAll('.sequence-toggle').forEach(button => {
        button.textContent = button.textContent.replace('▶', '▼');
    });
}

function collapseAll() {
    document.querySelectorAll('.sequence-content').forEach(content => {
        content.style.display = 'none';
    });
    document.querySelectorAll('.sequence-toggle').forEach(button => {
        button.textContent = button.textContent.replace('▼', '▶');
    });
}

function toggleDebug(button) {
    const content = button.nextElementSibling;
    const isExpanded = content.style.display !== 'none';
    content.style.display = isExpanded ? 'none' : 'block';
    button.textContent = button.textContent.replace(
        isExpanded ? '▼' : '▶',
        isExpanded ? '▶' : '▼'
    );
}

function togglePreview(button) {
    const content = button.nextElementSibling;
    const isExpanded = content.style.display !== 'none';
    content.style.display = isExpanded ? 'none' : 'block';
    button.textContent = button.textContent.replace(
        isExpanded ? '▼' : '▶',
        isExpanded ? '▶' : '▼'
    );
}

// Frame navigation functionality
document.addEventListener('DOMContentLoaded', function() {
    const slider = document.getElementById('frameSlider');
    const frameNumber = document.getElementById('frameNumber');
    const previewImage = document.getElementById('previewImage');

    if (slider && frameNumber && previewImage && window.frameData && window.frameData.length > 1) {
        slider.addEventListener('input', function() {
            const frame = parseInt(this.value);
            previewImage.src = 'data:image/jpeg;base64,' + window.frameData[frame];
            frameNumber.textContent = (frame + 1).toString();
        });

        // Add keyboard navigation
        document.addEventListener('keydown', function(e) {
            if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
                const newValue = Math.max(0, parseInt(slider.value) - 1);
                slider.value = newValue;
                slider.dispatchEvent(new Event('input'));
            } else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
                const newValue = Math.min(window.frameData.length - 1, parseInt(slider.value) + 1);
                slider.value = newValue;
                slider.dispatchEvent(new Event('input'));
            }
        });
    }
}); 