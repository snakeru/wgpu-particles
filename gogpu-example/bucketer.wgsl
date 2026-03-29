// SPDX-FileCopyrightText: 2026 Alexey Nezhdanov
// SPDX-License-Identifier: AGPL-3.0-only
const CellCap: u32 = 4u;

struct UniformData {
    particleCount: u32,
    gridWidth: u32,
    gridHeight: u32,
};

@group(0) @binding(0) var<uniform> globalData: UniformData;
@group(0) @binding(1) var<storage, read> particles: array<vec2<f32>>;
@group(0) @binding(2) var<storage, read_write> cellStorage: array<atomic<u32>>;

// FIXME: result.exchanged fails to compile, hence this hack.
fn try_fill_slot(idx: u32, value: u32) -> bool {
    loop {
        let result = atomicCompareExchangeWeak(&cellStorage[idx], 0, value);
        if (result.old_value != 0) { return result.old_value == value; }
    }
}

// The bucketer's goal is to sort particles into buckets as long as they fit.
// Full buckets might lead to dropped particles, this is OK.
// This stage assumes zeroed-out cellStorage.
@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let particleIdx = global_id.x;
    if (particleIdx==0 || particleIdx >= globalData.particleCount) { return; }

    // Compute cell index
    let pX = particles[particleIdx].x;
    let pY = particles[particleIdx].y; 
    if (pX<0f || pY<0f) { return; }
    let cellX = u32(pX);
    let cellY = u32(pY);
    if (cellX >= globalData.gridWidth || cellY >= globalData.gridHeight) { return; }
    let baseSlot = (cellY * globalData.gridWidth + cellX)*CellCap;
    for (var i = 0u; i < CellCap; i++) {
        if (try_fill_slot( baseSlot+i, particleIdx)) { return; }
    }
    // Drop the particle
}
