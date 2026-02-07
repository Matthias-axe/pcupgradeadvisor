// Theme Management
function initTheme() {
	const savedTheme = localStorage.getItem('theme') || 'light';
	applyTheme(savedTheme);
}

function applyTheme(theme) {
	if (theme === 'dark') {
		document.documentElement.setAttribute('data-theme', 'dark');
		document.getElementById('themeToggle').textContent = '☀️';
	} else {
		document.documentElement.removeAttribute('data-theme');
		document.getElementById('themeToggle').textContent = '🌙';
	}
	localStorage.setItem('theme', theme);
}

function toggleTheme() {
	const currentTheme = document.documentElement.getAttribute('data-theme');
	const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
	applyTheme(newTheme);
}

// Global data storage
let cpuData = [];
let gpuData = [];
let ramData = [];
let powerProfiles = [];

// Selected components
let selectedCPU = null;
let selectedGPU = null;
let selectedRAM = null;

// Tier mapping system to align component tiers for balanced systems
// Maps original tier (1-7) to display tier (can use fractional values)
// Based on real-world balanced pairings
const TIER_MAPPINGS = {
	cpu: {
		1: 1,
		2: 2,
		3: 3,
		4: 4,
		5: 5,
		6: 6,
		7: 7
	},
	gpu: {
		1: 1,
		2: 2,
		3: 3,
		4: 4,
		5: 5,
		6: 6,
		7: 7
	},
	ram: {
		1: 1,
		2: 2,
		3: 3,
		4: 4,
		5: 5,
		6: 6,
		7: 7
	}
};

// RAM tier 4+ is considered "good enough" - not a bottleneck
const RAM_GOOD_ENOUGH_TIER = 4;

// Get the display tier for a component
function getDisplayTier(component, type) {
	const mapping = TIER_MAPPINGS[type];
	if (!mapping) return component.tier;
	return mapping[component.tier] || component.tier;
}

// Get the original tier from a display tier (finds closest match)
function getOriginalTier(displayTier, type) {
	const mapping = TIER_MAPPINGS[type];
	if (!mapping) return displayTier;
	
	// Find the original tier that maps to this display tier
	for (let [originalTier, mappedTier] of Object.entries(mapping)) {
		if (mappedTier === displayTier) {
			return parseInt(originalTier);
		}
	}
	
	// If exact match not found, find closest
	let closest = 1;
	let minDiff = Infinity;
	for (let [originalTier, mappedTier] of Object.entries(mapping)) {
		const diff = Math.abs(mappedTier - displayTier);
		if (diff < minDiff) {
			minDiff = diff;
			closest = parseInt(originalTier);
		}
	}
	return closest;
}

// Load all JSON data on page load
async function loadData() {
	try {
		const [cpusRes, gpusRes, ramsRes, powerRes] = await Promise.all([
			fetch('data/cpuSorted.json'),
			fetch('data/gpuSorted.json'),
			fetch('data/ramSorted.json'),
			fetch('data/powerProfiles.json')
		]);

		if (!cpusRes.ok || !gpusRes.ok || !ramsRes.ok) {
			throw new Error('Failed to load JSON data');
		}

		cpuData = await cpusRes.json();
		gpuData = await gpusRes.json();
		ramData = await ramsRes.json();
		powerProfiles = await powerRes.json();

		console.log('Data loaded successfully');
		console.log(`CPUs: ${cpuData.length}, GPUs: ${gpuData.length}, RAM: ${ramData.length}, Power Profiles: ${powerProfiles.length}`);

		populateDropdowns();
		populateFilterOptions();
		setupEventListeners();
	} catch (err) {
		console.error('Error loading data:', err);
		alert('Failed to load component data. Please refresh the page.');
	}
}

// Populate filter options
function populateFilterOptions() {
	// Initial population
	updateCPUSeriesFilter();
	updateGPUChipsetFilter();
	updateGPUCardManufacturerFilter();
	updateRAMKitFilter();
	updateRAMCapacityFilter();
	updateRAMDDRFilter();
	updateRAMSpeedFilter();
	updateRAMManufacturerFilter();
}

// Update CPU series filter based on brand selection
function updateCPUSeriesFilter() {
	const brandFilter = document.getElementById('cpuBrandFilter').value;
	const cpuSeriesSet = new Set();
	
	cpuData.forEach(cpu => {
		const name = cpu.name;
		
		// Only include CPUs matching the brand filter
		if (brandFilter === 'AMD' && !name.includes('AMD') && !name.includes('Ryzen')) return;
		if (brandFilter === 'Intel' && !name.includes('Intel') && !name.includes('Core')) return;
		
		// Extract series
		if (name.includes('Ryzen 5')) cpuSeriesSet.add('Ryzen 5');
		else if (name.includes('Ryzen 7')) cpuSeriesSet.add('Ryzen 7');
		else if (name.includes('Ryzen 9')) cpuSeriesSet.add('Ryzen 9');
		else if (name.includes('Ryzen 3')) cpuSeriesSet.add('Ryzen 3');
		else if (name.includes('Core i3')) cpuSeriesSet.add('Core i3');
		else if (name.includes('Core i5')) cpuSeriesSet.add('Core i5');
		else if (name.includes('Core i7')) cpuSeriesSet.add('Core i7');
		else if (name.includes('Core i9')) cpuSeriesSet.add('Core i9');
	});
	
	const cpuSeriesFilter = document.getElementById('cpuSeriesFilter');
	const currentValue = cpuSeriesFilter.value;
	cpuSeriesFilter.innerHTML = '<option value="">All Series</option>';
	
	const sortedSeries = Array.from(cpuSeriesSet).sort();
	sortedSeries.forEach(series => {
		const option = document.createElement('option');
		option.value = series;
		option.textContent = series;
		cpuSeriesFilter.appendChild(option);
	});
	
	// Restore previous selection if still valid
	if (currentValue && sortedSeries.includes(currentValue)) {
		cpuSeriesFilter.value = currentValue;
	}
}

// Update GPU chipset filter based on manufacturer selection
function updateGPUChipsetFilter() {
	const manufacturerFilter = document.getElementById('gpuChipsetManufacturerFilter').value;
	const gpuChipsetSet = new Set();
	
	gpuData.forEach(gpu => {
		const chipset = gpu.chipset || '';
		
		// Only include GPUs matching the manufacturer filter
		if (manufacturerFilter === 'NVIDIA' && !chipset.includes('GeForce') && !chipset.includes('RTX') && !chipset.includes('GTX')) return;
		if (manufacturerFilter === 'AMD' && !chipset.includes('Radeon') && !chipset.includes('RX')) return;
		
		if (chipset) {
			gpuChipsetSet.add(chipset);
		}
	});
	
	const gpuChipsetFilter = document.getElementById('gpuChipsetFilter');
	const currentValue = gpuChipsetFilter.value;
	gpuChipsetFilter.innerHTML = '<option value="">All Chipsets</option>';
	
	const sortedChipsets = Array.from(gpuChipsetSet).sort();
	sortedChipsets.forEach(chipset => {
		const option = document.createElement('option');
		option.value = chipset;
		option.textContent = chipset;
		gpuChipsetFilter.appendChild(option);
	});
	
	// Restore previous selection if still valid
	if (currentValue && sortedChipsets.includes(currentValue)) {
		gpuChipsetFilter.value = currentValue;
	}
}

// Update GPU card manufacturer filter based on selections
function updateGPUCardManufacturerFilter() {
	const chipsetManufacturerFilter = document.getElementById('gpuChipsetManufacturerFilter').value;
	const chipsetFilter = document.getElementById('gpuChipsetFilter').value;
	const cardManufacturerSet = new Set();
	
	gpuData.forEach(gpu => {
		const chipset = gpu.chipset || '';
		
		// Filter by chipset manufacturer if selected
		if (chipsetManufacturerFilter) {
			if (chipsetManufacturerFilter === 'NVIDIA' && !chipset.includes('GeForce') && !chipset.includes('RTX') && !chipset.includes('GTX')) return;
			if (chipsetManufacturerFilter === 'AMD' && !chipset.includes('Radeon') && !chipset.includes('RX')) return;
		}
		
		// Filter by chipset if selected
		if (chipsetFilter && chipset !== chipsetFilter) return;
		
		// Extract card manufacturer (first word of name)
		const cardManufacturer = gpu.name.split(' ')[0];
		cardManufacturerSet.add(cardManufacturer);
	});
	
	const cardManufacturerFilterEl = document.getElementById('gpuCardManufacturerFilter');
	const currentValue = cardManufacturerFilterEl.value;
	cardManufacturerFilterEl.innerHTML = '<option value="">All Card Manufacturers</option>';
	
	const sortedManufacturers = Array.from(cardManufacturerSet).sort();
	sortedManufacturers.forEach(manufacturer => {
		const option = document.createElement('option');
		option.value = manufacturer;
		option.textContent = manufacturer;
		cardManufacturerFilterEl.appendChild(option);
	});
	
	// Restore previous selection if still valid
	if (currentValue && sortedManufacturers.includes(currentValue)) {
		cardManufacturerFilterEl.value = currentValue;
	}
}

// Update RAM capacity filter
// Update RAM kit configuration filter
function updateRAMKitFilter() {
	if (!ramData || ramData.length === 0) return;
	
	const kitSet = new Set();
	
	ramData.forEach(ram => {
		if (!ram.modules) return;
		const modules = ram.modules.split(',');
		if (modules.length < 1) return;
		const count = parseInt(modules[0]);
		if (!isNaN(count)) {
			if (count === 1) {
				kitSet.add('1');
			} else if (count === 2) {
				kitSet.add('2');
			} else if (count === 4) {
				kitSet.add('4');
			} else if (count === 8) {
				kitSet.add('8');
			} else {
				kitSet.add(count.toString());
			}
		}
	});
	
	const kitFilter = document.getElementById('ramKitFilter');
	if (!kitFilter) return;
	const currentValue = kitFilter.value;
	kitFilter.innerHTML = '<option value="">All Kits</option>';
	
	const sortedKits = Array.from(kitSet).sort((a, b) => parseInt(a) - parseInt(b));
	sortedKits.forEach(kit => {
		const option = document.createElement('option');
		option.value = kit;
		if (kit === '1') {
			option.textContent = 'Single Stick (1x)';
		} else {
			option.textContent = `${kit}x Kit`;
		}
		kitFilter.appendChild(option);
	});
	
	if (currentValue && sortedKits.includes(currentValue)) {
		kitFilter.value = currentValue;
	}
}

function updateRAMCapacityFilter() {
	if (!ramData || ramData.length === 0) return;
	
	const kitFilter = document.getElementById('ramKitFilter').value;
	const capacitySet = new Set();
	
	// Check if CPU is selected for DDR compatibility
	const cpuDDRType = selectedCPU ? (selectedCPU.ramType || '').toUpperCase() : '';
	
	ramData.forEach(ram => {
		if (!ram.modules) return;
		const modules = ram.modules.split(',');
		if (modules.length < 2) return;
		const count = parseInt(modules[0]);
		const capacityPerStick = parseInt(modules[1]);
		
		// Filter by kit if selected
		if (kitFilter && count !== parseInt(kitFilter)) return;
		
		// Filter by DDR compatibility if CPU is selected
		if (cpuDDRType) {
			const ramDDRType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
			if (!cpuDDRType.includes(ramDDRType)) return;
		}
		
		// Calculate TOTAL capacity (count × capacity per stick)
		const totalCapacity = count * capacityPerStick;
		if (!isNaN(totalCapacity)) {
			capacitySet.add(totalCapacity);
		}
	});
	
	const capacityFilter = document.getElementById('ramCapacityFilter');
	if (!capacityFilter) return;
	const currentValue = capacityFilter.value;
	capacityFilter.innerHTML = '<option value="">All Capacities</option>';
	
	const sortedCapacities = Array.from(capacitySet).sort((a, b) => a - b);
	sortedCapacities.forEach(capacity => {
		const option = document.createElement('option');
		option.value = capacity;
		option.textContent = `${capacity} GB`;
		capacityFilter.appendChild(option);
	});
	
	if (currentValue && sortedCapacities.includes(parseInt(currentValue))) {
		capacityFilter.value = currentValue;
	}
}

// Update RAM DDR filter based on capacity
function updateRAMDDRFilter() {
	if (!ramData || ramData.length === 0) return;
	
	const kitFilter = document.getElementById('ramKitFilter').value;
	const capacityFilter = document.getElementById('ramCapacityFilter').value;
	
	// Check if CPU is selected for DDR compatibility
	const cpuDDRType = selectedCPU ? (selectedCPU.ramType || '').toUpperCase() : '';
	
	const ddrSet = new Set();
	
	ramData.forEach(ram => {
		if (!ram.modules) return;
		const modules = ram.modules.split(',');
		if (modules.length < 2) return;
		const count = parseInt(modules[0]);
		const capacityPerStick = parseInt(modules[1]);
		const totalCapacity = count * capacityPerStick;
		
		// Filter by kit if selected
		if (kitFilter && count !== parseInt(kitFilter)) return;
		
		// Filter by TOTAL capacity if selected
		if (capacityFilter && totalCapacity !== parseInt(capacityFilter)) return;
		
		// Filter by CPU DDR compatibility if CPU is selected
		if (cpuDDRType) {
			const ramDDRType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
			if (!cpuDDRType.includes(ramDDRType)) return;
		}
		
		// Map generation to DDR type
		if (ram.generation <= 9) {
			ddrSet.add('DDR4');
		} else {
			ddrSet.add('DDR5');
		}
	});
	
	const ddrFilter = document.getElementById('ramDDRFilter');
	if (!ddrFilter) return;
	const currentValue = ddrFilter.value;
	ddrFilter.innerHTML = '<option value="">All DDR Types</option>';
	
	const sortedDDR = Array.from(ddrSet).sort();
	sortedDDR.forEach(ddr => {
		const option = document.createElement('option');
		option.value = ddr;
		option.textContent = ddr;
		ddrFilter.appendChild(option);
	});
	
	if (currentValue && sortedDDR.includes(currentValue)) {
		ddrFilter.value = currentValue;
	}
}

// Update RAM speed filter based on capacity and DDR
function updateRAMSpeedFilter() {
	if (!ramData || ramData.length === 0) return;
	
	const kitFilter = document.getElementById('ramKitFilter').value;
	const capacityFilter = document.getElementById('ramCapacityFilter').value;
	const ddrFilter = document.getElementById('ramDDRFilter').value;
	
	// Check if CPU is selected for DDR compatibility
	const cpuDDRType = selectedCPU ? (selectedCPU.ramType || '').toUpperCase() : '';
	
	const speedSet = new Set();
	
	ramData.forEach(ram => {
		if (!ram.modules) return;
		const modules = ram.modules.split(',');
		if (modules.length < 2) return;
		const count = parseInt(modules[0]);
		const capacityPerStick = parseInt(modules[1]);
		const totalCapacity = count * capacityPerStick;
		
		// Filter by kit if selected
		if (kitFilter && count !== parseInt(kitFilter)) return;
		
		// Filter by TOTAL capacity if selected
		if (capacityFilter && totalCapacity !== parseInt(capacityFilter)) return;
		
		// Filter by DDR type if selected
		if (ddrFilter) {
			if (ddrFilter === 'DDR4' && ram.generation > 9) return;
			if (ddrFilter === 'DDR5' && ram.generation <= 9) return;
		}
		
		// Filter by CPU DDR compatibility if CPU is selected
		if (cpuDDRType) {
			const ramDDRType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
			if (!cpuDDRType.includes(ramDDRType)) return;
		}
		
		if (ram.speed) {
			speedSet.add(ram.speed);
		}
	});
	
	const speedFilter = document.getElementById('ramSpeedFilter');
	if (!speedFilter) return;
	const currentValue = speedFilter.value;
	speedFilter.innerHTML = '<option value="">All Speeds</option>';
	
	const sortedSpeeds = Array.from(speedSet).sort((a, b) => {
		const speedA = parseInt(a.split(',')[1]);
		const speedB = parseInt(b.split(',')[1]);
		return speedA - speedB;
	});
	
	sortedSpeeds.forEach(speed => {
		const option = document.createElement('option');
		option.value = speed;
		const speedMHz = speed.split(',')[1];
		option.textContent = `${speedMHz} MHz`;
		speedFilter.appendChild(option);
	});
	
	if (currentValue && sortedSpeeds.includes(currentValue)) {
		speedFilter.value = currentValue;
	}
}

// Update RAM manufacturer filter based on other selections
function updateRAMManufacturerFilter() {
	if (!ramData || ramData.length === 0) return;
	
	const kitFilter = document.getElementById('ramKitFilter').value;
	const capacityFilter = document.getElementById('ramCapacityFilter').value;
	const ddrFilter = document.getElementById('ramDDRFilter').value;
	const speedFilter = document.getElementById('ramSpeedFilter').value;
	
	// Check if CPU is selected for DDR compatibility
	const cpuDDRType = selectedCPU ? (selectedCPU.ramType || '').toUpperCase() : '';
	
	const manufacturerSet = new Set();
	
	ramData.forEach(ram => {
		if (!ram.modules || !ram.name) return;
		const modules = ram.modules.split(',');
		if (modules.length < 2) return;
		const count = parseInt(modules[0]);
		const capacityPerStick = parseInt(modules[1]);
		const totalCapacity = count * capacityPerStick;
		
		// Filter by kit if selected
		if (kitFilter && count !== parseInt(kitFilter)) return;
		
		// Filter by TOTAL capacity if selected
		if (capacityFilter && totalCapacity !== parseInt(capacityFilter)) return;
		
		// Filter by DDR type if selected
		if (ddrFilter) {
			if (ddrFilter === 'DDR4' && ram.generation > 9) return;
			if (ddrFilter === 'DDR5' && ram.generation <= 9) return;
		}
		
		// Filter by CPU DDR compatibility if CPU is selected
		if (cpuDDRType) {
			const ramDDRType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
			if (!cpuDDRType.includes(ramDDRType)) return;
		}
		
		// Filter by speed if selected
		if (speedFilter && ram.speed !== speedFilter) return;
		
		// Extract manufacturer (first word of name)
		const manufacturer = ram.name.split(' ')[0];
		if (manufacturer) {
			manufacturerSet.add(manufacturer);
		}
	});
	
	const manufacturerFilter = document.getElementById('ramManufacturerFilter');
	if (!manufacturerFilter) return;
	const currentValue = manufacturerFilter.value;
	manufacturerFilter.innerHTML = '<option value="">All Manufacturers</option>';
	
	const sortedManufacturers = Array.from(manufacturerSet).sort();
	sortedManufacturers.forEach(manufacturer => {
		const option = document.createElement('option');
		option.value = manufacturer;
		option.textContent = manufacturer;
		manufacturerFilter.appendChild(option);
	});
	
	if (currentValue && sortedManufacturers.includes(currentValue)) {
		manufacturerFilter.value = currentValue;
	}
}

// Filter and populate CPU dropdown
function filterCPUs() {
	const brandFilter = document.getElementById('cpuBrandFilter').value;
	const seriesFilter = document.getElementById('cpuSeriesFilter').value;
	
	const filtered = cpuData.filter(cpu => {
		const name = cpu.name;
		
		// Brand filter
		if (brandFilter) {
			if (brandFilter === 'AMD' && !name.includes('AMD') && !name.includes('Ryzen')) return false;
			if (brandFilter === 'Intel' && !name.includes('Intel') && !name.includes('Core')) return false;
		}
		
		// Series filter
		if (seriesFilter && !name.includes(seriesFilter)) return false;
		
		return true;
	});
	
	const cpuSelect = document.getElementById('cpuSelect');
	cpuSelect.innerHTML = '<option value="">Select your CPU...</option>';
	filtered.forEach(cpu => {
		const idx = cpuData.indexOf(cpu);
		const option = document.createElement('option');
		option.value = idx;
		option.textContent = `${cpu.name}`;
		cpuSelect.appendChild(option);
	});
}

// Handle CPU brand filter change
function handleCPUBrandChange() {
	updateCPUSeriesFilter();
	filterCPUs();
}

// Handle GPU chipset manufacturer filter change
function handleGPUChipsetManufacturerChange() {
	updateGPUChipsetFilter();
	updateGPUCardManufacturerFilter();
	filterGPUs();
}

// Handle GPU chipset filter change
function handleGPUChipsetChange() {
	updateGPUCardManufacturerFilter();
	filterGPUs();
}

// Filter and populate GPU dropdown
function filterGPUs() {
	const chipsetManufacturerFilter = document.getElementById('gpuChipsetManufacturerFilter').value;
	const chipsetFilter = document.getElementById('gpuChipsetFilter').value;
	const cardManufacturerFilter = document.getElementById('gpuCardManufacturerFilter').value;
	
	const filtered = gpuData.filter(gpu => {
		const chipset = gpu.chipset || '';
		const cardManufacturer = gpu.name.split(' ')[0];
		
		// Chipset manufacturer filter (NVIDIA/AMD)
		if (chipsetManufacturerFilter) {
			if (chipsetManufacturerFilter === 'NVIDIA' && !chipset.includes('GeForce') && !chipset.includes('RTX') && !chipset.includes('GTX')) return false;
			if (chipsetManufacturerFilter === 'AMD' && !chipset.includes('Radeon') && !chipset.includes('RX')) return false;
		}
		
		// Chipset filter
		if (chipsetFilter && chipset !== chipsetFilter) return false;
		
		// Card manufacturer filter
		if (cardManufacturerFilter && cardManufacturer !== cardManufacturerFilter) return false;
		
		return true;
	});
	
	const gpuSelect = document.getElementById('gpuSelect');
	gpuSelect.innerHTML = '<option value="">Select your GPU...</option>';
	filtered.forEach(gpu => {
		const idx = gpuData.indexOf(gpu);
		const option = document.createElement('option');
		option.value = idx;
		option.textContent = `${gpu.name} - ${gpu.chipset}`;
		gpuSelect.appendChild(option);
	});
}

// Filter and populate RAM dropdown
function filterRAM() {
	if (!ramData || ramData.length === 0) return;
	
	const kitFilter = document.getElementById('ramKitFilter').value;
	const capacityFilter = document.getElementById('ramCapacityFilter').value;
	const ddrFilter = document.getElementById('ramDDRFilter').value;
	const speedFilter = document.getElementById('ramSpeedFilter').value;
	const manufacturerFilter = document.getElementById('ramManufacturerFilter').value;
	
	// Check if CPU is selected for DDR compatibility
	const cpuDDRType = selectedCPU ? (selectedCPU.ramType || '').toUpperCase() : '';
	
	const filtered = ramData.filter(ram => {
		if (!ram.modules || !ram.name) return false;
		const modules = ram.modules.split(',');
		if (modules.length < 2) return false;
		const count = parseInt(modules[0]);
		const capacityPerStick = parseInt(modules[1]);
		const totalCapacity = count * capacityPerStick;
		const manufacturer = ram.name.split(' ')[0];
		
		// Kit filter
		if (kitFilter && count !== parseInt(kitFilter)) return false;
		
		// Capacity filter (using TOTAL capacity)
		if (capacityFilter && totalCapacity !== parseInt(capacityFilter)) return false;
		
		// DDR type filter
		if (ddrFilter) {
			if (ddrFilter === 'DDR4' && ram.generation > 9) return false;
			if (ddrFilter === 'DDR5' && ram.generation <= 9) return false;
		}
		
		// CPU DDR compatibility filter
		if (cpuDDRType) {
			const ramDDRType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
			if (!cpuDDRType.includes(ramDDRType)) return false;
		}
		
		// Speed filter
		if (speedFilter && ram.speed !== speedFilter) return false;
		
		// Manufacturer filter
		if (manufacturerFilter && manufacturer !== manufacturerFilter) return false;
		
		return true;
	});
	
	const ramSelect = document.getElementById('ramSelect');
	if (!ramSelect) return;
	ramSelect.innerHTML = '<option value="">Select your RAM...</option>';
	const uniqueMap = new Map();
	filtered.forEach((ram) => {
		const key = `${ram.name}|${ram.modules}|${ram.speed || ''}|${ram.generation}`;
		if (!uniqueMap.has(key)) {
			uniqueMap.set(key, ram);
		}
	});

	uniqueMap.forEach((ram) => {
		const idx = ramData.indexOf(ram);
		const option = document.createElement('option');
		option.value = idx;
		const modules = ram.modules.split(',');
		let count = parseInt(modules[0]);
		const capacityPerStick = modules[1];
		const totalCapacity = count * parseInt(capacityPerStick);
		// Treat 8x kits as 4x (motherboard limitation)
		if (count === 8) count = 4;
		const ddrType = ram.generation <= 9 ? 'DDR4' : 'DDR5';
		const speedMHz = ram.speed ? ram.speed.split(',')[1] : 'N/A';
		option.textContent = `${ram.name} - ${totalCapacity}GB (${count}x${capacityPerStick}GB) ${ddrType}-${speedMHz}`;
		ramSelect.appendChild(option);
	});
}

// Handle RAM kit filter change
function handleRAMKitChange() {
	updateRAMCapacityFilter();
	updateRAMDDRFilter();
	updateRAMSpeedFilter();
	updateRAMManufacturerFilter();
	filterRAM();
}

// Handle RAM capacity filter change
function handleRAMCapacityChange() {
	updateRAMDDRFilter();
	updateRAMSpeedFilter();
	updateRAMManufacturerFilter();
	filterRAM();
}

// Handle RAM DDR filter change
function handleRAMDDRChange() {
	updateRAMSpeedFilter();
	updateRAMManufacturerFilter();
	filterRAM();
}

// Handle RAM speed filter change
function handleRAMSpeedChange() {
	updateRAMManufacturerFilter();
	filterRAM();
}

// Populate the component dropdowns
function populateDropdowns() {
	// CPU Dropdown
	filterCPUs();

	// GPU Dropdown
	filterGPUs();

	// RAM Dropdown
	filterRAM();
}

// Footer info panel setup
function setupFooterPanel() {
	const panel = document.getElementById('footerPanel');
	const titleEl = document.getElementById('footerPanelTitle');
	const bodyEl = document.getElementById('footerPanelBody');
	const closeBtn = document.getElementById('footerPanelClose');
	const buttons = document.querySelectorAll('[data-footer-panel]');

	if (!panel || !titleEl || !bodyEl || buttons.length === 0) return;

	const contentMap = {
		about: {
			title: 'About',
			body: '<p><strong>About PC Upgrade Advisor</strong></p>' +
				'<p>PC Upgrade Advisor is an independent, one-person project designed to help users make informed PC hardware upgrade decisions.</p>' +
				'<p>All recommendations are based solely on technical specifications and performance data. This site does not accept sponsored placements or paid product promotions.</p>' +
				'<p><strong>Contact</strong><br />If you experience issues or have questions, you can reach us at:<br /><a href="mailto:pcupgradeadvisor@gmail.com">pcupgradeadvisor@gmail.com</a></p>'
		},
		privacy: {
			title: 'Privacy Policy',
			body: '<p><strong>Privacy Policy</strong></p>' +
				'<p>PC Upgrade Advisor respects your privacy.</p>' +
				'<p>We do not collect personal information, do not require user accounts, and do not sell user data.</p>' +
				'<p><strong>Affiliate Links</strong><br />This website contains affiliate links. When you click these links, third-party platforms such as Amazon may place cookies on your device to track purchases. We do not control these cookies.</p>' +
				'<p><strong>Third-Party Services</strong><br />We may link to third-party websites (such as Amazon). Their privacy practices are governed by their own policies.</p>' +
				'<p><strong>Contact</strong><br />If you have any questions about this Privacy Policy, you can contact us at:<br /><a href="mailto:pcupgradeadvisor@gmail.com">pcupgradeadvisor@gmail.com</a></p>'
		}
	};

	const closePanel = () => {
		panel.classList.add('hidden');
		panel.setAttribute('aria-hidden', 'true');
		panel.dataset.activeKey = '';
	};

	const openPanel = (key) => {
		const content = contentMap[key];
		if (!content) return;

		const isOpen = !panel.classList.contains('hidden');
		if (isOpen && panel.dataset.activeKey === key) {
			closePanel();
			return;
		}

		panel.dataset.activeKey = key;
		titleEl.textContent = content.title;
		bodyEl.innerHTML = content.body;
		panel.classList.remove('hidden');
		panel.setAttribute('aria-hidden', 'false');
	};

	buttons.forEach((button) => {
		button.addEventListener('click', () => openPanel(button.dataset.footerPanel));
	});

	if (closeBtn) {
		closeBtn.addEventListener('click', closePanel);
	}
}

// Setup event listeners
function setupEventListeners() {
	// Filter listeners
	document.getElementById('cpuBrandFilter').addEventListener('change', handleCPUBrandChange);
	document.getElementById('cpuSeriesFilter').addEventListener('change', filterCPUs);
	document.getElementById('gpuChipsetManufacturerFilter').addEventListener('change', handleGPUChipsetManufacturerChange);
	document.getElementById('gpuChipsetFilter').addEventListener('change', handleGPUChipsetChange);
	document.getElementById('gpuCardManufacturerFilter').addEventListener('change', filterGPUs);
	document.getElementById('ramKitFilter').addEventListener('change', handleRAMKitChange);
	document.getElementById('ramCapacityFilter').addEventListener('change', handleRAMCapacityChange);
	document.getElementById('ramDDRFilter').addEventListener('change', handleRAMDDRChange);
	document.getElementById('ramSpeedFilter').addEventListener('change', handleRAMSpeedChange);
	document.getElementById('ramManufacturerFilter').addEventListener('change', filterRAM);

	// Component selection listeners
	document.getElementById('cpuSelect').addEventListener('change', (e) => {
		if (e.target.value !== '') {
			selectedCPU = cpuData[parseInt(e.target.value)];
			displayComponentInfo('cpu', selectedCPU);
			// Refresh RAM filters based on CPU DDR compatibility
			updateRAMCapacityFilter();
			updateRAMDDRFilter();
			updateRAMSpeedFilter();
			updateRAMManufacturerFilter();
			filterRAM();
		} else {
			selectedCPU = null;
			document.getElementById('cpuInfo').innerHTML = '';
			// Refresh RAM filters when CPU is deselected
			updateRAMCapacityFilter();
			updateRAMDDRFilter();
			updateRAMSpeedFilter();
			updateRAMManufacturerFilter();
			filterRAM();
		}
	});

	document.getElementById('gpuSelect').addEventListener('change', (e) => {
		if (e.target.value !== '') {
			selectedGPU = gpuData[parseInt(e.target.value)];
			displayComponentInfo('gpu', selectedGPU);
		} else {
			selectedGPU = null;
			document.getElementById('gpuInfo').innerHTML = '';
		}
	});

	document.getElementById('ramSelect').addEventListener('change', (e) => {
		if (e.target.value !== '') {
			selectedRAM = ramData[parseInt(e.target.value)];
			displayComponentInfo('ram', selectedRAM);
		} else {
			selectedRAM = null;
			document.getElementById('ramInfo').innerHTML = '';
		}
	});

	// Analyze button
	document.getElementById('analyzeBtn').addEventListener('click', analyzeSystem);

	// Footer info panel
	setupFooterPanel();
}

// Display component information
function displayComponentInfo(type, component) {
	let html = '';
	const targetDiv = document.getElementById(`${type}Info`);

	if (type === 'cpu') {
		html = `${component.core_count} cores | ${parseFloat(component.boost_clock).toFixed(2)} GHz`;
	} else if (type === 'gpu') {
		html = `${component.memory}GB VRAM | ${component.chipset}`;
	} else {
		// Extract module info and treat 8x kits as 4x (motherboard limitation)
		const moduleParts = component.modules.split(',');
		let moduleCount = parseInt(moduleParts[0]);
		const moduleCapacity = moduleParts[1];
		if (moduleCount === 8) {
			moduleCount = 4; // Motherboards typically only have 4 slots
		}
		const moduleDisplay = `${moduleCount}x${moduleCapacity}GB`;
		html = `${component.speed} | ${moduleDisplay}`;
	}

	targetDiv.innerHTML = html;
}

// Get next available tier for a component (FIXED)
function getNextAvailableTier(currentTier, component, advancement) {
	let availableTiers;
	let componentType;

	if (component === 'CPU') {
		componentType = 'cpu';
		availableTiers = [...new Set(cpuData.map(c => getDisplayTier(c, 'cpu')))].sort((a, b) => a - b);
	} else if (component === 'GPU') {
		componentType = 'gpu';
		availableTiers = [...new Set(gpuData.map(g => getDisplayTier(g, 'gpu')))].sort((a, b) => a - b);
	} else {
		// RAM
		componentType = 'ram';
		availableTiers = [...new Set(ramData.map(r => getDisplayTier(r, 'ram')))].sort((a, b) => a - b);
	}

	// Calculate target tier
	let targetTier;
	if (advancement === 'max') {
		targetTier = Math.max(...availableTiers);
	} else {
		// For numeric advancement, find the Nth tier ABOVE current tier
		const advancementNum = parseInt(advancement);
		const currentIndex = availableTiers.findIndex(t => t >= currentTier);
		
		if (currentIndex === -1) {
			// Current tier not found, get first available
			targetTier = availableTiers[0];
		} else {
			// Move up by the advancement amount
			const targetIndex = currentIndex + advancementNum;
			if (targetIndex >= availableTiers.length) {
				// Cap at max tier
				targetTier = availableTiers[availableTiers.length - 1];
			} else {
				targetTier = availableTiers[targetIndex];
			}
		}
	}

	return targetTier;
}

// Main analysis function
function analyzeSystem() {
	// Check if all components are selected
	if (!selectedCPU || !selectedGPU || !selectedRAM) {
		alert('Please select all three components (CPU, GPU, RAM) before analyzing.');
		return;
	}

	// Use display tiers for analysis
	const cpuTier = getDisplayTier(selectedCPU, 'cpu');
	const gpuTier = getDisplayTier(selectedGPU, 'gpu');
	const ramTier = getDisplayTier(selectedRAM, 'ram');
	const advancement = document.querySelector('input[name="advancement"]:checked').value;

	// Detect bottleneck
	const tiers = { CPU: cpuTier, GPU: gpuTier, RAM: ramTier };
	
	// RAM tier 4+ is considered sufficient, so exclude from bottleneck detection
	const ramIsSufficient = ramTier >= RAM_GOOD_ENOUGH_TIER;
	const minTier = ramIsSufficient ? Math.min(cpuTier, gpuTier) : Math.min(cpuTier, gpuTier, ramTier);
	let bottleneckComponent = null;

	if (ramIsSufficient) {
		// Only compare CPU vs GPU if RAM is sufficient
		if (cpuTier === minTier && cpuTier < gpuTier) bottleneckComponent = 'CPU';
		else if (gpuTier === minTier && gpuTier < cpuTier) bottleneckComponent = 'GPU';
	} else {
		// Include RAM in bottleneck detection
		if (cpuTier === minTier && (cpuTier < gpuTier || cpuTier < ramTier)) bottleneckComponent = 'CPU';
		else if (gpuTier === minTier && (gpuTier < cpuTier || gpuTier < ramTier)) bottleneckComponent = 'GPU';
		else if (ramTier === minTier && (ramTier < cpuTier || ramTier < gpuTier)) bottleneckComponent = 'RAM';
	}

	// Display bottleneck analysis
	displayBottleneckAnalysis(tiers, bottleneckComponent);

	// Get recommendations
	if (!bottleneckComponent) {
		// System is balanced
		bottleneckComponent = 'CPU'; // Default to CPU for balanced systems
	}

	const recommendedTier = getNextAvailableTier(tiers[bottleneckComponent], bottleneckComponent, advancement);
	displayRecommendations(bottleneckComponent, tiers[bottleneckComponent], recommendedTier, cpuTier, advancement);

	// Show results section
	document.getElementById('resultsSection').classList.remove('hidden');
}

// Display bottleneck analysis
function displayBottleneckAnalysis(tiers, bottleneck) {
	const card = document.getElementById('bottleneckAnalysis');
	let html = '<h3>System Analysis</h3>';

	const parts = [
		{ name: 'CPU', tier: tiers.CPU },
		{ name: 'GPU', tier: tiers.GPU },
		{ name: 'RAM', tier: tiers.RAM }
	];
	const minTier = Math.min(tiers.CPU, tiers.GPU, tiers.RAM);
	const maxTier = Math.max(tiers.CPU, tiers.GPU, tiers.RAM);
	const isBalanced = minTier === maxTier;
	const underpowered = parts.filter(p => p.tier === minTier && !isBalanced).map(p => p.name);
	const balanced = parts.filter(p => p.tier > minTier).map(p => p.name);

	if (isBalanced) {
		html += `
			<div style="text-align: center; padding: 20px;">
				<div class="balanced-indicator">✓ System Perfectly Balanced</div>
				<p>Your system is balanced.</p>
			</div>
		`;
	} else {
		html += `<p>Your system isn’t fully balanced.</p>`;
		html += `<p><div class="bottleneck-indicator">⚠️ Bottleneck: ${bottleneck}</div></p>`;
		html += `<p>Your <strong>${bottleneck}</strong> is limiting performance. Upgrading it will give the most noticeable improvement.</p>`;
	}

	card.innerHTML = html;
}

// Calculate component score based on specs (same formula as backend)
function calculateScore(component, type) {
	if (type === 'CPU') {
		const maxBoost = Math.max(...cpuData.map(c => parseFloat(c.boost_clock) || 0));
		const minBoost = Math.min(...cpuData.map(c => parseFloat(c.boost_clock) || 0));
		const maxCores = Math.max(...cpuData.map(c => c.core_count || 0));
		const minCores = Math.min(...cpuData.map(c => c.core_count || 0));
		const maxGen = Math.max(...cpuData.map(c => c.generation || 0));
		const minGen = Math.min(...cpuData.map(c => c.generation || 0));

		const boostNorm = (parseFloat(component.boost_clock) || 0 - minBoost) / (maxBoost - minBoost || 1);
		const coreNorm = (component.core_count - minCores) / (maxCores - minCores || 1);
		const genNorm = (component.generation - minGen) / (maxGen - minGen || 1);

		return (boostNorm * 0.60) + (coreNorm * 0.30) + (genNorm * 0.10);
	} else if (type === 'GPU') {
		const maxBoost = Math.max(...gpuData.map(g => parseFloat(g.boost_clock) || 0));
		const minBoost = Math.min(...gpuData.map(g => parseFloat(g.boost_clock) || 0));
		const maxMem = Math.max(...gpuData.map(g => g.memory || 0));
		const minMem = Math.min(...gpuData.map(g => g.memory || 0));
		const maxGen = Math.max(...gpuData.map(g => g.generation || 0));
		const minGen = Math.min(...gpuData.map(g => g.generation || 0));

		const boostNorm = (parseFloat(component.boost_clock) || 0 - minBoost) / (maxBoost - minBoost || 1);
		const memNorm = (component.memory - minMem) / (maxMem - minMem || 1);
		const genNorm = (component.generation - minGen) / (maxGen - minGen || 1);

		return (boostNorm * 0.65) + (memNorm * 0.25) + (genNorm * 0.10);
	} else if (type === 'RAM') {
		// For RAM, prioritize speed and capacity
		const speedNum = parseInt(component.speed?.replace(/[^0-9]/g, '') || '0');
		const maxSpeed = Math.max(...ramData.map(r => parseInt(r.speed?.replace(/[^0-9]/g, '') || '0')));
		const minSpeed = Math.min(...ramData.map(r => parseInt(r.speed?.replace(/[^0-9]/g, '') || '2000')));
		
		const speedNorm = (speedNum - minSpeed) / (maxSpeed - minSpeed || 1);
		
		// Extract memory capacity from name (simplified)
		const memMatch = component.name.match(/(\d+)\s*GB/);
		const memGB = memMatch ? parseInt(memMatch[1]) : 16;
		const maxMem = Math.max(...ramData.map(r => parseInt(r.name?.match(/(\d+)\s*GB/)?.[1] || '0')));
		const minMem = Math.min(...ramData.map(r => parseInt(r.name?.match(/(\d+)\s*GB/)?.[1] || '8')));
		
		const memNorm = (memGB - minMem) / (maxMem - minMem || 1);
		
		return (speedNorm * 0.65) + (memNorm * 0.35);
	}
	return 0;
}

function getSelectedEffortLevel() {
	return document.querySelector('input[name="effort"]:checked')?.value || 'simple';
}

function getEffortRank(level) {
	if (level === 'any') return 4;
	if (level === 'complex') return 3;
	if (level === 'moderate') return 2;
	return 1;
}

function isEffortAllowed(requiredLevel, selectedLevel) {
	if (selectedLevel === 'any') return true;
	return getEffortRank(requiredLevel) <= getEffortRank(selectedLevel);
}

function getRamDdrType(ram) {
	if (!ram) return null;
	if (typeof ram.generation === 'number') {
		return ram.generation <= 9 ? 'DDR4' : 'DDR5';
	}
	if (typeof ram.speed === 'string') {
		if (ram.speed.includes('5,') || ram.speed.includes('5.')) return 'DDR5';
		if (ram.speed.includes('4,') || ram.speed.includes('4.')) return 'DDR4';
	}
	return null;
}

function isRamCompatibleWithCpu(ram, cpu) {
	if (!ram || !cpu || !cpu.ramType) return true;
	const ramType = getRamDdrType(ram);
	if (!ramType) return true;
	return cpu.ramType.includes(ramType);
}

function getPsuRecommendation(cpuTier, gpuTier) {
	const profile = powerProfiles.find(p => p.cpuTier === cpuTier && p.gpuTier === gpuTier);
	return profile ? profile.recommendedPsu : null;
}

function getUpgradeEffort(component, product) {
	const requiredParts = [];
	const notes = [];
	let requiredLevel = 'simple';

	if (component === 'CPU') {
		if (selectedCPU && product.socket && selectedCPU.socket && product.socket !== selectedCPU.socket) {
			requiredParts.push('Motherboard');
		}
		if (selectedRAM && product.ramType && !isRamCompatibleWithCpu(selectedRAM, product)) {
			requiredParts.push('RAM');
		}
		if (requiredParts.length > 0) {
			requiredLevel = 'complex';
		}
	} else if (component === 'RAM') {
		if (selectedCPU && !isRamCompatibleWithCpu(product, selectedCPU)) {
			requiredParts.push('CPU/Motherboard');
			requiredLevel = 'complex';
		}
	} else if (component === 'GPU') {
		if (selectedCPU && selectedGPU) {
			const currentPsu = getPsuRecommendation(selectedCPU.tier, selectedGPU.tier);
			const targetPsu = getPsuRecommendation(selectedCPU.tier, product.tier);
			if (currentPsu && targetPsu && targetPsu > currentPsu) {
				requiredParts.push('PSU');
				requiredLevel = 'moderate';
				notes.push(`Estimated PSU need: ${targetPsu}W (current estimate: ${currentPsu}W)`);
			} else if (!currentPsu || !targetPsu) {
				notes.push('PSU check required for this upgrade');
			}
		}
	}

	return { requiredLevel, requiredParts, notes };
}

// Get best products from tier that are actually upgrades
function getUpgradeProducts(component, currentComponent, recommendedTier, type) {
	let products = [];
	const currentScore = calculateScore(currentComponent, type);
	const componentTypeKey = type.toLowerCase();
	const selectedEffort = getSelectedEffortLevel();

	if (type === 'CPU') {
		products = cpuData.filter(c => getDisplayTier(c, componentTypeKey) === recommendedTier && calculateScore(c, 'CPU') > currentScore);
	} else if (type === 'GPU') {
		products = gpuData.filter(g => getDisplayTier(g, componentTypeKey) === recommendedTier && calculateScore(g, 'GPU') > currentScore);
	} else if (type === 'RAM') {
		const seen = new Set();
		products = ramData.filter(r => {
			const key = `${r.name}`;
			if (seen.has(key)) return false;
			seen.add(key);
			return getDisplayTier(r, componentTypeKey) === recommendedTier && calculateScore(r, 'RAM') > currentScore;
		});
	}

	products = products.filter(product => {
		const effort = getUpgradeEffort(component, product);
		return isEffortAllowed(effort.requiredLevel, selectedEffort);
	});

	return products.sort((a, b) => {
		const scoreA = calculateScore(a, type);
		const scoreB = calculateScore(b, type);
		return scoreB - scoreA; // Sort by score descending
	}).slice(0, 5);
}

// Display recommendations
function displayRecommendations(component, currentTier, recommendedTier, cpuTier, advancement) {
	const card = document.getElementById('recommendationCard');
	const container = document.getElementById('productsSection');
	const selectedEffort = getSelectedEffortLevel();
	let finalTier = recommendedTier;
	const upgradeSizeLabel = advancement === 'max' ? 'Extreme' : advancement === '3' ? 'Large' : advancement === '2' ? 'Medium' : 'Small';
	const effortLabel = selectedEffort === 'any' ? 'Any effort' : `${selectedEffort.charAt(0).toUpperCase()}${selectedEffort.slice(1)} effort`;

	card.innerHTML = `
		<h3>Recommended Upgrade</h3>
		<p>${upgradeSizeLabel} upgrade for <strong>${component}</strong></p>
		<div class="recommendation-reason">
			<p><strong>Why this upgrade?</strong></p>
			<ul>
				<li>${component} is the current bottleneck.</li>
				<li>Upgrade size selected: ${upgradeSizeLabel}.</li>
				<li>Effort filter applied: ${effortLabel}.</li>
				<li>Compatibility and power checks are applied.</li>
			</ul>
		</div>
	`;

	// Get products for recommended tier that are verified upgrades
	let products = [];
	let componentName = '';
	let currentComponent = null;

	if (component === 'CPU') {
		componentName = 'CPUs';
		currentComponent = selectedCPU;
		products = getUpgradeProducts('CPU', currentComponent, recommendedTier, 'CPU');
	} else if (component === 'GPU') {
		componentName = 'GPUs';
		currentComponent = selectedGPU;
		products = getUpgradeProducts('GPU', currentComponent, recommendedTier, 'GPU');
	} else {
		componentName = 'RAM';
		currentComponent = selectedRAM;
		products = getUpgradeProducts('RAM', currentComponent, recommendedTier, 'RAM');
	}

	// If no verified upgrades in recommended tier, try next tier up
	const componentTypeKey = component.toLowerCase();
	let maxDisplayTier;
	if (component === 'CPU') {
		maxDisplayTier = Math.max(...cpuData.map(c => getDisplayTier(c, componentTypeKey)));
	} else if (component === 'GPU') {
		maxDisplayTier = Math.max(...gpuData.map(g => getDisplayTier(g, componentTypeKey)));
	} else {
		maxDisplayTier = Math.max(...ramData.map(r => getDisplayTier(r, componentTypeKey)));
	}
	
	if (products.length === 0 && recommendedTier < maxDisplayTier) {
		const nextTier = recommendedTier + 1;
		if (component === 'CPU') {
			products = getUpgradeProducts('CPU', currentComponent, nextTier, 'CPU');
		} else if (component === 'GPU') {
			products = getUpgradeProducts('GPU', currentComponent, nextTier, 'GPU');
		} else {
			products = getUpgradeProducts('RAM', currentComponent, nextTier, 'RAM');
		}
		if (products.length > 0) {
			finalTier = nextTier;
			card.innerHTML = `<h3>Recommended Upgrade</h3><p>${upgradeSizeLabel} upgrade for <strong>${component}</strong></p>`;
		}
	}

	// Display products
	let html = `<h3>Top ${componentName} for a ${upgradeSizeLabel.toLowerCase()} upgrade</h3><p class="effort-summary">Effort filter: <strong>${effortLabel}</strong></p>`;
	if (products.length === 0) {
			html += '<p style="color: #888;">No verified upgrades available for the selected effort level. Consider a larger upgrade size or higher effort, or check specifications manually.</p>';
	} else {
		html += '<div class="products-container">';
		products.forEach((product, index) => {
			html += createProductCard(product, component, index + 1, cpuTier);
		});
		html += '</div>';
	}
	container.innerHTML = html;

	// Show next steps
	displayNextSteps(component, finalTier, currentTier, cpuTier);
}

// Create a product card
function createProductCard(product, component, rank, cpuTier) {
	const effort = getUpgradeEffort(component, product);
	let html = `<div class="product-card">
		<div class="product-rank">#${rank} Pick</div>
		<div class="product-name">${product.name}</div>`;

	html += `
		<div class="product-effort ${effort.requiredLevel}">
			<span class="spec-label">Effort:</span>
			<span class="spec-value">${effort.requiredLevel.charAt(0).toUpperCase()}${effort.requiredLevel.slice(1)}</span>
		</div>`;

	if (component === 'CPU') {
		html += `
			<div class="product-specs">
				<div class="product-spec">
					<span class="spec-label">Socket:</span>
					<span class="spec-value">${product.socket}</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">Cores:</span>
					<span class="spec-value">${product.core_count}</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">Boost Clock:</span>
					<span class="spec-value">${parseFloat(product.boost_clock).toFixed(2)} GHz</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">TDP:</span>
					<span class="spec-value">${product.tdp}W</span>
				</div>
			</div>`;

		// Compatibility warning: Only show if user selected RAM and it doesn't match this CPU's requirements
		if (selectedRAM && product.ramType) {
			const selectedRAMType = getRamDdrType(selectedRAM) || 'Unknown DDR';
			const cpuRequiresRAMType = product.ramType;
			if (selectedRAMType !== cpuRequiresRAMType) {
				html += `<div class="product-warning">
					<strong>⚠️ Compatibility Issue:</strong> This CPU requires ${cpuRequiresRAMType} RAM, but you selected ${selectedRAMType}
				</div>`;
			}
		}

		if (selectedCPU && product.socket && selectedCPU.socket && product.socket !== selectedCPU.socket) {
			html += `<div class="product-warning">
				<strong>⚠️ Socket Mismatch:</strong> Requires a ${product.socket} motherboard (current CPU is ${selectedCPU.socket}).
			</div>`;
		}
	} else if (component === 'GPU') {
		html += `
			<div class="product-specs">
				<div class="product-spec">
					<span class="spec-label">Chipset:</span>
					<span class="spec-value">${product.chipset}</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">VRAM:</span>
					<span class="spec-value">${product.memory}GB</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">Boost Clock:</span>
					<span class="spec-value">${product.boost_clock} MHz</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">TDP:</span>
					<span class="spec-value">${product.tdp}W</span>
				</div>
			</div>`;

		// PSU recommendation: Compare estimated PSU needs vs current system
		if (selectedCPU && selectedGPU) {
			const currentPsu = getPsuRecommendation(selectedCPU.tier, selectedGPU.tier);
			const targetPsu = getPsuRecommendation(selectedCPU.tier, product.tier);
			if (currentPsu && targetPsu && targetPsu > currentPsu) {
				html += `<div class="product-warning">
					<strong>⚠️ PSU Upgrade Likely:</strong> Estimated PSU need ${targetPsu}W (current estimate ${currentPsu}W)
				</div>`;
			} else if (targetPsu && targetPsu >= 850) {
				html += `<div class="product-warning">
					<strong>⚠️ High Power Requirement:</strong> Estimated PSU need ${targetPsu}W
				</div>`;
			}
		}
	} else {
		// RAM
		html += `
			<div class="product-specs">
				<div class="product-spec">
					<span class="spec-label">Speed:</span>
					<span class="spec-value">${product.speed}</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">Modules:</span>
					<span class="spec-value">${product.modules}</span>
				</div>
				<div class="product-spec">
					<span class="spec-label">Latency:</span>
					<span class="spec-value">CAS ${product.cas_latency}</span>
				</div>
			</div>`;

		if (selectedCPU && !isRamCompatibleWithCpu(product, selectedCPU)) {
			html += `<div class="product-warning">
				<strong>⚠️ Compatibility Issue:</strong> This RAM is not compatible with your selected CPU (${selectedCPU.ramType}).
			</div>`;
		}
	}

	if (effort.requiredParts.length > 0) {
		html += `
			<div class="product-required">
				<strong>Additional parts likely needed:</strong> ${effort.requiredParts.join(', ')}
			</div>`;
	}

	if (effort.notes.length > 0) {
		effort.notes.forEach(note => {
			html += `<div class="product-note">${note}</div>`;
		});
	}

	// Product link placeholder (will be filled in when links are added)
	html += `
		<a href="#" class="product-link">View Product on Amazon</a>
	</div>`;

	return html;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
	initTheme();
	loadData();
	document.getElementById('themeToggle').addEventListener('click', toggleTheme);
	document.getElementById('analyzeBtn').addEventListener('click', analyzeSystem);
});

// Display next steps
function displayNextSteps(component, currentRecommendation, previousTier, cpuTier) {
	const section = document.getElementById('nextStepsSection');

	let html = '<h3>What\'s Next?</h3>';

	if (currentRecommendation < 10) {
		html += `<p>After upgrading your <strong>${component}</strong>, the next bottleneck will likely be a different component.</p>
		<p>Consider planning your next upgrade path to maintain system balance.</p>`;
	} else {
		html += `<p>🎉 <strong>You're reaching the top end!</strong></p>
		<p>Your system will be at peak performance. Further upgrades would be for cutting-edge features or specific use cases.</p>`;
	}

	section.innerHTML = html;
}

// Initialize on page load
window.addEventListener('DOMContentLoaded', loadData);

