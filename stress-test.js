const fs = require('fs');
const path = require('path');

const root = __dirname;
const cpuData = JSON.parse(fs.readFileSync(path.join(root, 'data', 'cpuSorted.json'), 'utf8'));
const gpuData = JSON.parse(fs.readFileSync(path.join(root, 'data', 'gpuSorted.json'), 'utf8'));
const ramData = JSON.parse(fs.readFileSync(path.join(root, 'data', 'ramSorted.json'), 'utf8'));
const powerProfiles = JSON.parse(fs.readFileSync(path.join(root, 'data', 'powerProfiles.json'), 'utf8'));

const RAM_GOOD_ENOUGH_TIER = 4;
const TIER_MAPPINGS = {
	cpu: {1:1,2:2,3:3,4:4,5:5,6:6,7:7},
	gpu: {1:1,2:2,3:3,4:4,5:5,6:6,7:7},
	ram: {1:1,2:2,3:3,4:4,5:5,6:6,7:7}
};

function getDisplayTier(component, type) {
	const mapping = TIER_MAPPINGS[type];
	return mapping?.[component.tier] ?? component.tier;
}

function calculateScore(component, type, datasets) {
	if (type === 'CPU') {
		const { cpuData } = datasets;
		const maxBoost = Math.max(...cpuData.map(c => parseFloat(c.boost_clock) || 0));
		const minBoost = Math.min(...cpuData.map(c => parseFloat(c.boost_clock) || 0));
		const maxCores = Math.max(...cpuData.map(c => c.core_count || 0));
		const minCores = Math.min(...cpuData.map(c => c.core_count || 0));
		const maxGen = Math.max(...cpuData.map(c => c.generation || 0));
		const minGen = Math.min(...cpuData.map(c => c.generation || 0));

		const boostNorm = ((parseFloat(component.boost_clock) || 0) - minBoost) / (maxBoost - minBoost || 1);
		const coreNorm = (component.core_count - minCores) / (maxCores - minCores || 1);
		const genNorm = (component.generation - minGen) / (maxGen - minGen || 1);

		return (boostNorm * 0.60) + (coreNorm * 0.30) + (genNorm * 0.10);
	}
	if (type === 'GPU') {
		const { gpuData } = datasets;
		const maxBoost = Math.max(...gpuData.map(g => parseFloat(g.boost_clock) || 0));
		const minBoost = Math.min(...gpuData.map(g => parseFloat(g.boost_clock) || 0));
		const maxMem = Math.max(...gpuData.map(g => g.memory || 0));
		const minMem = Math.min(...gpuData.map(g => g.memory || 0));
		const maxGen = Math.max(...gpuData.map(g => g.generation || 0));
		const minGen = Math.min(...gpuData.map(g => g.generation || 0));

		const boostNorm = ((parseFloat(component.boost_clock) || 0) - minBoost) / (maxBoost - minBoost || 1);
		const memNorm = (component.memory - minMem) / (maxMem - minMem || 1);
		const genNorm = (component.generation - minGen) / (maxGen - minGen || 1);

		return (boostNorm * 0.65) + (memNorm * 0.25) + (genNorm * 0.10);
	}
	if (type === 'RAM') {
		const { ramData } = datasets;
		const speedNum = parseInt(component.speed?.replace(/[^0-9]/g, '') || '0', 10);
		const maxSpeed = Math.max(...ramData.map(r => parseInt(r.speed?.replace(/[^0-9]/g, '') || '0', 10)));
		const minSpeed = Math.min(...ramData.map(r => parseInt(r.speed?.replace(/[^0-9]/g, '') || '2000', 10)));

		const speedNorm = (speedNum - minSpeed) / (maxSpeed - minSpeed || 1);

		const memMatch = component.name.match(/(\d+)\s*GB/);
		const memGB = memMatch ? parseInt(memMatch[1], 10) : 16;
		const maxMem = Math.max(...ramData.map(r => parseInt(r.name?.match(/(\d+)\s*GB/)?.[1] || '0', 10)));
		const minMem = Math.min(...ramData.map(r => parseInt(r.name?.match(/(\d+)\s*GB/)?.[1] || '8', 10)));

		const memNorm = (memGB - minMem) / (maxMem - minMem || 1);
		return (speedNorm * 0.65) + (memNorm * 0.35);
	}
	return 0;
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

function getUpgradeEffort(component, product, selectedCPU, selectedGPU, selectedRAM) {
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
		if (requiredParts.length > 0) requiredLevel = 'complex';
	}
	if (component === 'RAM') {
		if (selectedCPU && !isRamCompatibleWithCpu(product, selectedCPU)) {
			requiredParts.push('CPU/Motherboard');
			requiredLevel = 'complex';
		}
	}
	if (component === 'GPU') {
		if (selectedCPU && selectedGPU) {
			const currentPsu = getPsuRecommendation(selectedCPU.tier, selectedGPU.tier);
			const targetPsu = getPsuRecommendation(selectedCPU.tier, product.tier);
			if (currentPsu && targetPsu && targetPsu > currentPsu) {
				requiredParts.push('PSU');
				requiredLevel = 'moderate';
				notes.push(`Estimated PSU need: ${targetPsu}W (current estimate: ${currentPsu}W)`);
			}
		}
	}

	return { requiredLevel, requiredParts, notes };
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

function getNextAvailableTier(currentTier, component, advancement, datasets) {
	const data = component === 'CPU' ? datasets.cpuData : component === 'GPU' ? datasets.gpuData : datasets.ramData;
	const typeKey = component.toLowerCase();
	const availableTiers = Array.from(new Set(data.map(d => getDisplayTier(d, typeKey)))).sort((a,b)=>a-b);
	const maxTier = availableTiers[availableTiers.length - 1];

	if (advancement === 'max') return maxTier;
	const target = Math.min(currentTier + advancement, maxTier);
	if (availableTiers.includes(target)) return target;
	const higher = availableTiers.find(t => t > target);
	return higher ?? maxTier;
}

function getUpgradeProducts(component, currentComponent, recommendedTier, datasets, selectedEffort, selectedCPU, selectedGPU, selectedRAM) {
	const currentScore = calculateScore(currentComponent, component, datasets);
	const typeKey = component.toLowerCase();
	let products = [];

	if (component === 'CPU') {
		products = datasets.cpuData.filter(c => getDisplayTier(c, typeKey) === recommendedTier && calculateScore(c, 'CPU', datasets) > currentScore);
	} else if (component === 'GPU') {
		products = datasets.gpuData.filter(g => getDisplayTier(g, typeKey) === recommendedTier && calculateScore(g, 'GPU', datasets) > currentScore);
	} else {
		const seen = new Set();
		products = datasets.ramData.filter(r => {
			const key = `${r.name}`;
			if (seen.has(key)) return false;
			seen.add(key);
			return getDisplayTier(r, typeKey) === recommendedTier && calculateScore(r, 'RAM', datasets) > currentScore;
		});
	}

	products = products.filter(product => {
		const effort = getUpgradeEffort(component, product, selectedCPU, selectedGPU, selectedRAM);
		return isEffortAllowed(effort.requiredLevel, selectedEffort);
	});

	return products.sort((a, b) => calculateScore(b, component, datasets) - calculateScore(a, component, datasets)).slice(0, 5);
}

function runStressTest(iterations = 1000) {
	const datasets = { cpuData, gpuData, ramData };
	const effortLevels = ['simple', 'moderate', 'complex', 'any'];
	const results = {};

	effortLevels.forEach(level => {
		results[level] = {
			total: 0,
			noProducts: 0,
			fallbackTierUsed: 0,
			errors: 0
		};
	});

	const rand = (arr) => arr[Math.floor(Math.random() * arr.length)];
	const advancements = [1, 2, 3, 'max'];

	for (let i = 0; i < iterations; i++) {
		const selectedCPU = rand(cpuData);
		const selectedGPU = rand(gpuData);
		const selectedRAM = rand(ramData);
		const cpuTier = getDisplayTier(selectedCPU, 'cpu');
		const gpuTier = getDisplayTier(selectedGPU, 'gpu');
		const ramTier = getDisplayTier(selectedRAM, 'ram');

		const ramIsSufficient = ramTier >= RAM_GOOD_ENOUGH_TIER;
		const minTier = ramIsSufficient ? Math.min(cpuTier, gpuTier) : Math.min(cpuTier, gpuTier, ramTier);
		let bottleneckComponent = null;

		if (ramIsSufficient) {
			if (cpuTier === minTier && cpuTier < gpuTier) bottleneckComponent = 'CPU';
			else if (gpuTier === minTier && gpuTier < cpuTier) bottleneckComponent = 'GPU';
		} else {
			if (cpuTier === minTier && (cpuTier < gpuTier || cpuTier < ramTier)) bottleneckComponent = 'CPU';
			else if (gpuTier === minTier && (gpuTier < cpuTier || gpuTier < ramTier)) bottleneckComponent = 'GPU';
			else if (ramTier === minTier && (ramTier < cpuTier || ramTier < gpuTier)) bottleneckComponent = 'RAM';
		}

		if (!bottleneckComponent) bottleneckComponent = 'CPU';
		const advancement = rand(advancements);

		effortLevels.forEach(level => {
			results[level].total++;
			try {
				const currentTier = bottleneckComponent === 'CPU' ? cpuTier : bottleneckComponent === 'GPU' ? gpuTier : ramTier;
				const recommendedTier = getNextAvailableTier(currentTier, bottleneckComponent, advancement, datasets);
				let products = getUpgradeProducts(bottleneckComponent, bottleneckComponent === 'CPU' ? selectedCPU : bottleneckComponent === 'GPU' ? selectedGPU : selectedRAM, recommendedTier, datasets, level, selectedCPU, selectedGPU, selectedRAM);
				if (products.length === 0) {
					const maxTier = bottleneckComponent === 'CPU'
						? Math.max(...cpuData.map(c => getDisplayTier(c, 'cpu')))
						: bottleneckComponent === 'GPU'
						? Math.max(...gpuData.map(g => getDisplayTier(g, 'gpu')))
						: Math.max(...ramData.map(r => getDisplayTier(r, 'ram')));
					if (recommendedTier < maxTier) {
						const fallbackTier = recommendedTier + 1;
						products = getUpgradeProducts(bottleneckComponent, bottleneckComponent === 'CPU' ? selectedCPU : bottleneckComponent === 'GPU' ? selectedGPU : selectedRAM, fallbackTier, datasets, level, selectedCPU, selectedGPU, selectedRAM);
						if (products.length > 0) results[level].fallbackTierUsed++;
					}
				}
				if (products.length === 0) results[level].noProducts++;
			} catch (err) {
				results[level].errors++;
			}
		});
	}

	return results;
}

const iterations = parseInt(process.argv[2] || '1000', 10);
const results = runStressTest(iterations);

console.log(`Stress Test Completed: ${iterations} iterations per effort level`);
Object.entries(results).forEach(([level, data]) => {
	console.log(`\nEffort: ${level}`);
	console.log(`Total cases: ${data.total}`);
	console.log(`No products found: ${data.noProducts}`);
	console.log(`Fallback tier used: ${data.fallbackTierUsed}`);
	console.log(`Errors: ${data.errors}`);
});
