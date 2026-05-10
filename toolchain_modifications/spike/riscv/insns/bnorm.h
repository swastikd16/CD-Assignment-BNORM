require_rv64;

// Read the Memory Alignment addresses from the Integer registers
uint64_t dims_addr = RS1;
uint64_t params_addr = RS2;

// Load array boundary from RAM
uint32_t N = MMU.load<uint32_t>(dims_addr);

// Load the array pointers from RAM
uint64_t X_ptr = MMU.load<uint64_t>(params_addr + 0);
uint64_t Y_ptr = MMU.load<uint64_t>(params_addr + 8);

// Parse the Learnable Parameters natively via MMU extraction
float mu, var, eps, gamma, beta;
uint32_t bits;

// Instead of memcpy (which requires cstring), we can use softfloat cast or type punning
auto load_float = [&](uint64_t addr) -> float {
    uint32_t b = MMU.load<uint32_t>(addr);
    union { uint32_t i; float f; } u;
    u.i = b;
    return u.f;
};

mu = load_float(params_addr + 16);
var = load_float(params_addr + 20);
eps = load_float(params_addr + 24);
gamma = load_float(params_addr + 28);
beta = load_float(params_addr + 32);

// Evaluate Full Batch Normalization formula across the Batch
for (uint32_t i = 0; i < N; i++) {
    uint32_t x_bits = MMU.load<uint32_t>(X_ptr + i*4);
    union { uint32_t i; float f; } ux;
    ux.i = x_bits;
    float x_val = ux.f;
    
    // Core Formula Computation
    
    float x_hat = (x_val - mu) / __builtin_sqrtf(var + eps);
    float y_val = (gamma * x_hat) + beta;
    
    union { uint32_t i; float f; } uy;
    uy.f = y_val;
    
    // Commit the output float map back to RAM
    MMU.store<uint32_t>(Y_ptr + i*4, uy.i);
}

// Write status mapping to return register
WRITE_RD(1);
