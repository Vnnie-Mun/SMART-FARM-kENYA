// Main JavaScript for Flask Scaffolding App

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all components
    initializeAnimations();
    initializeTooltips();
    initializeFormValidation();
    initializeThemeToggle();
    initializeSearchFunctionality();
    initializeTableEnhancements();
    initializeProgressBars();
    
    console.log('Flask Scaffolding App initialized successfully!');
});

// Animation Initialization
function initializeAnimations() {
    // Add fade-in animation to cards
    const cards = document.querySelectorAll('.card');
    cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 0.1}s`;
        card.classList.add('fade-in');
    });
    
    // Add bounce-in animation to buttons
    const buttons = document.querySelectorAll('.btn-primary, .btn-success');
    buttons.forEach(button => {
        button.addEventListener('mouseenter', function() {
            this.classList.add('pulse');
        });
        
        button.addEventListener('mouseleave', function() {
            this.classList.remove('pulse');
        });
    });
}

// Tooltips Initialization
function initializeTooltips() {
    // Initialize Bootstrap tooltips if available
    if (typeof bootstrap !== 'undefined') {
        const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
        tooltipTriggerList.map(function (tooltipTriggerEl) {
            return new bootstrap.Tooltip(tooltipTriggerEl);
        });
    }
    
    // Add custom tooltips for action buttons
    const actionButtons = document.querySelectorAll('.btn-group .btn');
    actionButtons.forEach(button => {
        button.addEventListener('mouseenter', function() {
            const title = this.getAttribute('title');
            if (title) {
                showCustomTooltip(this, title);
            }
        });
        
        button.addEventListener('mouseleave', function() {
            hideCustomTooltip();
        });
    });
}

// Custom Tooltip Functions
function showCustomTooltip(element, text) {
    const tooltip = document.createElement('div');
    tooltip.className = 'custom-tooltip';
    tooltip.textContent = text;
    tooltip.style.cssText = `
        position: absolute;
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 0.5rem;
        border-radius: 0.25rem;
        font-size: 0.875rem;
        z-index: 1000;
        pointer-events: none;
        opacity: 0;
        transition: opacity 0.2s;
    `;
    
    document.body.appendChild(tooltip);
    
    const rect = element.getBoundingClientRect();
    tooltip.style.left = `${rect.left + rect.width / 2 - tooltip.offsetWidth / 2}px`;
    tooltip.style.top = `${rect.top - tooltip.offsetHeight - 5}px`;
    
    setTimeout(() => tooltip.style.opacity = '1', 10);
}

function hideCustomTooltip() {
    const tooltip = document.querySelector('.custom-tooltip');
    if (tooltip) {
        tooltip.remove();
    }
}

// Form Validation Enhancement
function initializeFormValidation() {
    const forms = document.querySelectorAll('form');
    
    forms.forEach(form => {
        const inputs = form.querySelectorAll('input, textarea, select');
        
        inputs.forEach(input => {
            // Real-time validation feedback
            input.addEventListener('input', function() {
                validateField(this);
            });
            
            input.addEventListener('blur', function() {
                validateField(this);
            });
        });
        
        // Enhanced form submission
        form.addEventListener('submit', function(e) {
            let isValid = true;
            
            inputs.forEach(input => {
                if (!validateField(input)) {
                    isValid = false;
                }
            });
            
            if (!isValid) {
                e.preventDefault();
                showFormError('Please correct the errors below.');
            } else {
                showLoadingState(form);
            }
        });
    });
}

// Field Validation
function validateField(field) {
    const value = field.value.trim();
    const type = field.type;
    const required = field.hasAttribute('required');
    let isValid = true;
    let message = '';
    
    // Remove existing feedback
    removeFieldFeedback(field);
    
    // Required field validation
    if (required && !value) {
        isValid = false;
        message = 'This field is required.';
    }
    
    // Email validation
    if (type === 'email' && value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(value)) {
            isValid = false;
            message = 'Please enter a valid email address.';
        }
    }
    
    // Username validation
    if (field.name === 'username' && value) {
        if (value.length < 3) {
            isValid = false;
            message = 'Username must be at least 3 characters long.';
        } else if (!/^[a-zA-Z0-9_]+$/.test(value)) {
            isValid = false;
            message = 'Username can only contain letters, numbers, and underscores.';
        }
    }
    
    // Add feedback
    addFieldFeedback(field, isValid, message);
    
    return isValid;
}

// Field Feedback Functions
function addFieldFeedback(field, isValid, message) {
    field.classList.remove('is-valid', 'is-invalid');
    field.classList.add(isValid ? 'is-valid' : 'is-invalid');
    
    if (!isValid && message) {
        const feedback = document.createElement('div');
        feedback.className = 'invalid-feedback';
        feedback.textContent = message;
        field.parentNode.appendChild(feedback);
    }
}

function removeFieldFeedback(field) {
    field.classList.remove('is-valid', 'is-invalid');
    const feedback = field.parentNode.querySelector('.invalid-feedback');
    if (feedback) {
        feedback.remove();
    }
}

// Form Error Display
function showFormError(message) {
    const existingAlert = document.querySelector('.form-error-alert');
    if (existingAlert) {
        existingAlert.remove();
    }
    
    const alert = document.createElement('div');
    alert.className = 'alert alert-danger alert-dismissible fade show form-error-alert';
    alert.innerHTML = `
        <i class="bi bi-exclamation-triangle me-2"></i>
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const form = document.querySelector('form');
    form.parentNode.insertBefore(alert, form);
    
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
        if (alert && alert.parentNode) {
            alert.remove();
        }
    }, 5000);
}

// Loading State
function showLoadingState(form) {
    const submitBtn = form.querySelector('button[type="submit"]');
    if (submitBtn) {
        const originalText = submitBtn.innerHTML;
        submitBtn.innerHTML = '<span class="loading me-2"></span>Processing...';
        submitBtn.disabled = true;
        
        // Store original text for potential restoration
        submitBtn.dataset.originalText = originalText;
    }
}

// Theme Toggle (Dark/Light Mode)
function initializeThemeToggle() {
    // Create theme toggle button
    const themeToggle = document.createElement('button');
    themeToggle.className = 'btn btn-outline-light btn-sm position-fixed';
    themeToggle.style.cssText = 'top: 20px; right: 20px; z-index: 1000; border-radius: 50%; width: 40px; height: 40px;';
    themeToggle.innerHTML = '<i class="bi bi-moon"></i>';
    themeToggle.title = 'Toggle Dark Mode';
    
    document.body.appendChild(themeToggle);
    
    // Check for saved theme preference
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
        document.body.setAttribute('data-theme', savedTheme);
        updateThemeIcon(themeToggle, savedTheme);
    }
    
    // Theme toggle functionality
    themeToggle.addEventListener('click', function() {
        const currentTheme = document.body.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        document.body.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        updateThemeIcon(this, newTheme);
    });
}

function updateThemeIcon(button, theme) {
    const icon = button.querySelector('i');
    icon.className = theme === 'dark' ? 'bi bi-sun' : 'bi bi-moon';
    button.title = theme === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode';
}

// Search Functionality
function initializeSearchFunctionality() {
    const searchInputs = document.querySelectorAll('input[type="search"], .search-input');
    
    searchInputs.forEach(input => {
        input.addEventListener('input', function() {
            const query = this.value.toLowerCase();
            const targetTable = this.dataset.target || 'table';
            const table = document.querySelector(targetTable);
            
            if (table) {
                filterTable(table, query);
            }
        });
    });
}

function filterTable(table, query) {
    const rows = table.querySelectorAll('tbody tr');
    
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        const shouldShow = text.includes(query);
        
        row.style.display = shouldShow ? '' : 'none';
        
        if (shouldShow) {
            row.classList.add('fade-in');
        }
    });
    
    // Show "no results" message if needed
    const visibleRows = table.querySelectorAll('tbody tr[style=""], tbody tr:not([style])');
    const noResultsRow = table.querySelector('.no-results-row');
    
    if (visibleRows.length === 0 && !noResultsRow && query) {
        const tbody = table.querySelector('tbody');
        const colCount = table.querySelectorAll('thead th').length;
        
        const noResults = document.createElement('tr');
        noResults.className = 'no-results-row';
        noResults.innerHTML = `
            <td colspan="${colCount}" class="text-center text-muted py-4">
                <i class="bi bi-search display-4 mb-2"></i>
                <p>No results found for "${query}"</p>
            </td>
        `;
        
        tbody.appendChild(noResults);
    } else if (noResultsRow && (visibleRows.length > 0 || !query)) {
        noResultsRow.remove();
    }
}

// Table Enhancements
function initializeTableEnhancements() {
    const tables = document.querySelectorAll('.table');
    
    tables.forEach(table => {
        // Add sorting functionality
        const headers = table.querySelectorAll('th[data-sort]');
        headers.forEach(header => {
            header.style.cursor = 'pointer';
            header.addEventListener('click', function() {
                sortTable(table, this.dataset.sort);
            });
        });
        
        // Add row hover effects
        const rows = table.querySelectorAll('tbody tr');
        rows.forEach(row => {
            row.addEventListener('mouseenter', function() {
                this.style.transform = 'scale(1.01)';
                this.style.boxShadow = '0 4px 8px rgba(0,0,0,0.1)';
            });
            
            row.addEventListener('mouseleave', function() {
                this.style.transform = '';
                this.style.boxShadow = '';
            });
        });
    });
}

// Table Sorting
function sortTable(table, column) {
    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));
    const headerCell = table.querySelector(`th[data-sort="${column}"]`);
    
    // Determine sort direction
    const isAscending = !headerCell.classList.contains('sort-asc');
    
    // Remove existing sort classes
    table.querySelectorAll('th').forEach(th => {
        th.classList.remove('sort-asc', 'sort-desc');
    });
    
    // Add new sort class
    headerCell.classList.add(isAscending ? 'sort-asc' : 'sort-desc');
    
    // Sort rows
    rows.sort((a, b) => {
        const aValue = a.children[getColumnIndex(table, column)].textContent.trim();
        const bValue = b.children[getColumnIndex(table, column)].textContent.trim();
        
        if (isAscending) {
            return aValue.localeCompare(bValue, undefined, { numeric: true });
        } else {
            return bValue.localeCompare(aValue, undefined, { numeric: true });
        }
    });
    
    // Reorder DOM
    rows.forEach(row => tbody.appendChild(row));
}

function getColumnIndex(table, column) {
    const headers = table.querySelectorAll('th');
    for (let i = 0; i < headers.length; i++) {
        if (headers[i].dataset.sort === column) {
            return i;
        }
    }
    return 0;
}

// Progress Bars
function initializeProgressBars() {
    const progressBars = document.querySelectorAll('.progress-bar');
    
    progressBars.forEach(bar => {
        const width = bar.dataset.width || bar.style.width;
        bar.style.width = '0%';
        
        setTimeout(() => {
            bar.style.width = width;
            bar.style.transition = 'width 1s ease-in-out';
        }, 100);
    });
}

// Utility Functions
function showNotification(message, type = 'info', duration = 3000) {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.cssText = 'top: 20px; left: 50%; transform: translateX(-50%); z-index: 1050; min-width: 300px;';
    notification.innerHTML = `
        <i class="bi bi-${getNotificationIcon(type)} me-2"></i>
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.appendChild(notification);
    
    // Auto-dismiss
    setTimeout(() => {
        if (notification && notification.parentNode) {
            notification.classList.remove('show');
            setTimeout(() => notification.remove(), 150);
        }
    }, duration);
}

function getNotificationIcon(type) {
    const icons = {
        'success': 'check-circle',
        'danger': 'exclamation-triangle',
        'warning': 'exclamation-triangle',
        'info': 'info-circle'
    };
    return icons[type] || 'info-circle';
}

// API Helper Functions
function makeRequest(url, options = {}) {
    const defaultOptions = {
        headers: {
            'Content-Type': 'application/json',
        },
    };
    
    return fetch(url, { ...defaultOptions, ...options })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.json();
        })
        .catch(error => {
            console.error('Request failed:', error);
            showNotification('Request failed. Please try again.', 'danger');
            throw error;
        });
}

// Export functions for use in templates
window.FlaskApp = {
    showNotification,
    makeRequest,
    showLoadingState,
    validateField
};