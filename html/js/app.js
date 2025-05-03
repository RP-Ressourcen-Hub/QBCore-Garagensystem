// Initialize variables
let categories = {};
let vehicles = [];
let selectedVehicle = null;
let garageLocations = [];
let isImpound = false;
let transferFee = 1000;
let impoundFee = 5000;
let selectedCategory = "all";
let searchQuery = "";
let garageLabel = "";
let locale = {};
let darkMode = true;
let uiConfig = {};

// Listen for NUI messages from the FiveM client
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.type) {
        case 'openGarage':
            openGarage(data);
            break;
        case 'setVehicles':
            setVehicles(data.vehicles);
            break;
        case 'closeGarage':
            closeGarage();
            break;
        default:
            break;
    }
});

// Initialize the UI
function initializeUI() {
    // Bind click events
    $('#spawn-vehicle').click(spawnVehicle);
    $('#preview-vehicle').click(previewVehicle);
    $('#transfer-vehicle').click(showTransferModal);
    $('#release-vehicle').click(showImpoundModal);
    $('#confirm-transfer').click(transferVehicle);
    $('#confirm-release').click(releaseFromImpound);
    $('#vehicle-search').on('input', function() {
        searchQuery = $(this).val().toLowerCase();
        filterVehicles();
    });
    
    // Set dark/light mode
    if (darkMode) {
        $('body').attr('data-bs-theme', 'dark');
    } else {
        $('body').attr('data-bs-theme', 'light');
    }
}

// Open the garage menu
function openGarage(data) {
    garageLabel = data.garageLabel;
    isImpound = data.isImpound;
    transferFee = data.transferFee;
    impoundFee = data.impoundFee;
    categories = data.categories;
    garageLocations = data.garageLocations;
    locale = data.locale;
    darkMode = data.darkMode;
    uiConfig = data;
    
    // Update UI text based on garage type
    if (isImpound) {
        $('.garage-title').text(locale.impoundTitle || "BESCHLAGNAHMTE FAHRZEUGE");
        $('#spawn-vehicle').text(locale.releaseVehicle || "Fahrzeug auslösen");
    } else {
        $('.garage-title').text(locale.title || "FAHRZEUG-GARAGE");
        $('#spawn-vehicle').text(locale.retrieveVehicle || "Fahrzeug auspaken");
    }
    
    // Set garage subtitle
    $('.garage-subtitle').text(garageLabel);
    
    // Set fee information in modals
    $('#transfer-fee').text(transferFee);
    $('#impound-fee').text(impoundFee);
    
    // Update buttons based on garage type
    if (isImpound) {
        $('#transfer-vehicle').addClass('d-none');
        $('#preview-vehicle').addClass('d-none');
        $('#release-vehicle').addClass('d-none');
    } else {
        $('#transfer-vehicle').removeClass('d-none');
        $('#preview-vehicle').removeClass('d-none');
        $('#release-vehicle').addClass('d-none');
    }
    
    // Create category list
    initializeCategories();
    
    // Populate garage locations for transfer
    populateGarageLocations();
    
    // Show the UI with animation
    $('body').removeClass('d-none').addClass('fade-in');
    
    // Show garage container
    $('.garage-container').addClass('slide-up');
}

// Initialize category list
function initializeCategories() {
    const categoriesList = $('#categories-list');
    categoriesList.empty();
    
    // Add "All" category
    const allCategory = $(`
        <div class="category-item ${selectedCategory === 'all' ? 'active' : ''}" data-category="all">
            <span class="category-icon"><i class="fas fa-th"></i></span>
            <span>${locale.categoryAll || "Alle"}</span>
        </div>
    `);
    categoriesList.append(allCategory);
    
    // Add all vehicle categories
    for (const [key, value] of Object.entries(categories)) {
        const categoryIcon = getCategoryIcon(key);
        const categoryItem = $(`
            <div class="category-item ${selectedCategory === key ? 'active' : ''}" data-category="${key}">
                <span class="category-icon"><i class="${categoryIcon}"></i></span>
                <span>${value}</span>
            </div>
        `);
        categoriesList.append(categoryItem);
    }
    
    // Add click event to categories
    $('.category-item').click(function() {
        const category = $(this).data('category');
        selectedCategory = category;
        setCategoryActive(category);
        filterVehicles();
    });
}

// Set category as active
function setCategoryActive(category) {
    $('.category-item').removeClass('active');
    $(`.category-item[data-category="${category}"]`).addClass('active');
}

// Get appropriate icon for category
function getCategoryIcon(category) {
    const icons = {
        'all': 'fas fa-th',
        'compacts': 'fas fa-car',
        'sedans': 'fas fa-car-side',
        'suvs': 'fas fa-truck',
        'coupes': 'fas fa-car',
        'muscle': 'fas fa-car',
        'sportsclassics': 'fas fa-car',
        'sports': 'fas fa-car-side',
        'super': 'fas fa-car',
        'motorcycles': 'fas fa-motorcycle',
        'offroad': 'fas fa-truck-monster',
        'industrial': 'fas fa-truck',
        'utility': 'fas fa-truck-pickup',
        'vans': 'fas fa-shuttle-van',
        'cycles': 'fas fa-bicycle',
        'boats': 'fas fa-ship',
        'helicopters': 'fas fa-helicopter',
        'planes': 'fas fa-plane',
        'service': 'fas fa-truck',
        'emergency': 'fas fa-ambulance',
        'military': 'fas fa-fighter-jet',
        'commercial': 'fas fa-truck-moving',
        'trains': 'fas fa-train'
    };
    
    return icons[category] || 'fas fa-car';
}

// Populate the vehicle list
function setVehicles(vehicleList) {
    vehicles = vehicleList;
    filterVehicles();
}

// Filter vehicles by category and search query
function filterVehicles() {
    const vehiclesGrid = $('#vehicles-grid');
    vehiclesGrid.empty();
    
    // Filter vehicles by category and search
    let filteredVehicles = vehicles;
    
    if (selectedCategory !== "all") {
        filteredVehicles = filteredVehicles.filter(vehicle => vehicle.category === selectedCategory);
    }
    
    if (searchQuery) {
        filteredVehicles = filteredVehicles.filter(vehicle => 
            vehicle.name.toLowerCase().includes(searchQuery) || 
            vehicle.plate.toLowerCase().includes(searchQuery)
        );
    }
    
    // Show or hide "no vehicles" message
    if (filteredVehicles.length === 0) {
        vehiclesGrid.append(`<div class="col-12"><div class="no-vehicles-message text-center p-5">
            <i class="fas fa-car fa-3x mb-3 text-muted"></i>
            <h4 class="text-muted">${isImpound ? locale.noImpoundedVehicles : locale.noVehicles}</h4>
        </div></div>`);
        
        // Reset selected vehicle
        selectedVehicle = null;
        updateVehicleInfo();
        return;
    }
    
    // Sort vehicles by status and name
    filteredVehicles.sort((a, b) => {
        // First by status (stored first, then out, then impounded)
        const statusOrder = { 'stored': 0, 'out': 1, 'impounded': 2 };
        if (statusOrder[a.status] !== statusOrder[b.status]) {
            return statusOrder[a.status] - statusOrder[b.status];
        }
        
        // Then by name
        return a.name.localeCompare(b.name);
    });
    
    // Add vehicles to grid
    filteredVehicles.forEach(vehicle => {
        const vehicleType = vehicle.type || 'car';
        const vehicleCard = $(`
            <div class="col">
                <div class="vehicle-card ${selectedVehicle && selectedVehicle.plate === vehicle.plate ? 'selected' : ''}" data-plate="${vehicle.plate}">
                    <div class="vehicle-status-badge status-${vehicle.status}">${vehicle.statusLabel}</div>
                    <div class="vehicle-image" style="background-image: url('img/vehicles/${vehicleType}.png')"></div>
                    <div class="vehicle-details">
                        <div class="vehicle-name">${vehicle.name}</div>
                        <div class="vehicle-plate">${vehicle.plate}</div>
                    </div>
                </div>
            </div>
        `);
        
        vehiclesGrid.append(vehicleCard);
    });
    
    // Add click event to vehicle cards
    $('.vehicle-card').click(function() {
        const plate = $(this).data('plate');
        const vehicle = vehicles.find(v => v.plate === plate);
        selectVehicle(vehicle);
    });
    
    // If we had a selected vehicle before, try to keep it selected if it's still in the list
    if (selectedVehicle) {
        const stillExists = filteredVehicles.some(v => v.plate === selectedVehicle.plate);
        if (!stillExists) {
            selectedVehicle = null;
            updateVehicleInfo();
        }
    }
}

// Select a vehicle
function selectVehicle(vehicle) {
    // Deselect all vehicles
    $('.vehicle-card').removeClass('selected');
    
    // Select the clicked vehicle
    $(`.vehicle-card[data-plate="${vehicle.plate}"]`).addClass('selected');
    
    // Update selected vehicle
    selectedVehicle = vehicle;
    
    // Update vehicle info
    updateVehicleInfo();
    
    // Enable/disable buttons based on vehicle status
    updateActionButtons();
}

// Update vehicle information panel
function updateVehicleInfo() {
    if (!selectedVehicle) {
        $('.vehicle-info').addClass('d-none');
        $('.no-vehicle-selected').removeClass('d-none');
        return;
    }
    
    $('.vehicle-info').removeClass('d-none');
    $('.no-vehicle-selected').addClass('d-none');
    
    // Update vehicle details
    $('#vehicle-plate').text(selectedVehicle.plate);
    
    // Update progress bars
    const fuel = selectedVehicle.fuel || 0;
    const engine = selectedVehicle.engine ? (selectedVehicle.engine / 10) : 0;
    const body = selectedVehicle.body ? (selectedVehicle.body / 10) : 0;
    
    $('#vehicle-fuel').css('width', `${fuel}%`).text(`${Math.round(fuel)}%`);
    $('#vehicle-engine').css('width', `${engine}%`).text(`${Math.round(engine)}%`);
    $('#vehicle-body').css('width', `${body}%`).text(`${Math.round(body)}%`);
    
    // Update status and location
    $('#vehicle-status').text(selectedVehicle.statusLabel).css('color', selectedVehicle.statusColor);
    $('#vehicle-location').text(selectedVehicle.garage);
}

// Update action buttons based on selected vehicle status
function updateActionButtons() {
    if (!selectedVehicle) {
        // No vehicle selected, disable all buttons
        $('#spawn-vehicle, #preview-vehicle, #transfer-vehicle, #release-vehicle').prop('disabled', true);
        return;
    }
    
    if (isImpound) {
        // In impound, only enable the release button
        $('#spawn-vehicle').prop('disabled', false);
        $('#preview-vehicle, #transfer-vehicle, #release-vehicle').prop('disabled', true);
    } else {
        // In regular garage
        if (selectedVehicle.status === 'stored') {
            // Vehicle is in garage, can spawn and preview
            $('#spawn-vehicle, #preview-vehicle, #transfer-vehicle').prop('disabled', false);
            $('#release-vehicle').prop('disabled', true);
        } else if (selectedVehicle.status === 'out') {
            // Vehicle is already out, disable spawn and preview
            $('#spawn-vehicle, #preview-vehicle, #transfer-vehicle').prop('disabled', true);
            $('#release-vehicle').prop('disabled', true);
        } else if (selectedVehicle.status === 'impounded') {
            // Vehicle is impounded, can only release
            $('#spawn-vehicle, #preview-vehicle, #transfer-vehicle').prop('disabled', true);
            $('#release-vehicle').prop('disabled', false);
        }
    }
}

// Spawn the selected vehicle
function spawnVehicle() {
    if (!selectedVehicle) return;
    
    if (isImpound) {
        showImpoundModal();
    } else {
        // Send message to FiveM client
        fetch('https://qb-garage/spawnVehicle', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                plate: selectedVehicle.plate
            })
        }).then(resp => resp.json()).then(resp => {
            if (resp.success) {
                closeGarage();
            }
        });
    }
}

// Preview the selected vehicle
function previewVehicle() {
    if (!selectedVehicle) return;
    
    // Send message to FiveM client
    fetch('https://qb-garage/previewVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            plate: selectedVehicle.plate
        })
    });
}

// Show transfer modal
function showTransferModal() {
    if (!selectedVehicle || selectedVehicle.status !== 'stored') return;
    
    // Show the modal
    const transferModal = new bootstrap.Modal(document.getElementById('transfer-modal'));
    transferModal.show();
}

// Transfer vehicle to another garage
function transferVehicle() {
    if (!selectedVehicle) return;
    
    const targetGarage = $('#garage-select').val();
    if (!targetGarage) return;
    
    // Send message to FiveM client
    fetch('https://qb-garage/transferVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            plate: selectedVehicle.plate,
            targetGarage: targetGarage
        })
    }).then(resp => resp.json()).then(resp => {
        if (resp.success) {
            // Close the modal
            const transferModal = bootstrap.Modal.getInstance(document.getElementById('transfer-modal'));
            transferModal.hide();
            
            // Update the vehicle status
            selectedVehicle.garage = targetGarage;
            updateVehicleInfo();
        }
    });
}

// Show impound modal
function showImpoundModal() {
    if (!selectedVehicle || (selectedVehicle.status !== 'impounded' && !isImpound)) return;
    
    // Show the modal
    const impoundModal = new bootstrap.Modal(document.getElementById('impound-modal'));
    impoundModal.show();
}

// Release vehicle from impound
function releaseFromImpound() {
    if (!selectedVehicle) return;
    
    // Send message to FiveM client
    fetch('https://qb-garage/releaseVehicle', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            plate: selectedVehicle.plate
        })
    }).then(resp => resp.json()).then(resp => {
        if (resp.success) {
            // Close the modal
            const impoundModal = bootstrap.Modal.getInstance(document.getElementById('impound-modal'));
            impoundModal.hide();
            
            // If in the impound menu, refresh the list by removing this vehicle
            if (isImpound) {
                vehicles = vehicles.filter(v => v.plate !== selectedVehicle.plate);
                selectedVehicle = null;
                filterVehicles();
                updateVehicleInfo();
            } else {
                // Update the vehicle status
                selectedVehicle.status = 'stored';
                selectedVehicle.statusLabel = locale.statusStored;
                selectedVehicle.statusColor = '#28a745';
                selectedVehicle.stored = true;
                selectedVehicle.impounded = false;
                updateVehicleInfo();
                updateActionButtons();
                filterVehicles(); // Refresh the list
            }
        }
    });
}

// Populate garage locations dropdown
function populateGarageLocations() {
    const garageSelect = $('#garage-select');
    garageSelect.empty();
    
    garageLocations.forEach(garage => {
        if (garage.id !== currentGarage) {
            garageSelect.append(`<option value="${garage.id}">${garage.label}</option>`);
        }
    });
}

// Close the garage menu
function closeGarage() {
    // Hide the UI with animation
    $('body').removeClass('fade-in').addClass('fade-out');
    $('.garage-container').removeClass('slide-up').addClass('slide-down');
    
    // Reset values
    selectedVehicle = null;
    selectedCategory = "all";
    searchQuery = "";
    
    // Hide UI after animation completes
    setTimeout(() => {
        $('body').addClass('d-none');
        
        // Send message to FiveM client
        fetch('https://qb-garage/closeGarage', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }, 300);
}

// Format number with commas
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Initialize when the document is ready
$(document).ready(function() {
    initializeUI();
    
    // Close on ESC key
    document.onkeyup = function(data) {
        if (data.which == 27) { // ESC key
            closeGarage();
        }
    };
});