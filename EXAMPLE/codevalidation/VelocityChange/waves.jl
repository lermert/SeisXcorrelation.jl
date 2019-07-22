export ricker, dampedSinusoid, sinc

"""

    ricker(;f::Float64=20.0, n::Int64=100, dt::Float64=0.001, nargout::Bool=false)

Generate a Ricker wavelet.

# Arguments
- `f::Float64,`    : Peak frequnecy
- `n::Int64`    : Number of points
- `dt::Float64`    : Sampling interval

# Output
- `s`::Array{Float64,1}    : Computed Ricker wavelet
- `t`::Array{Float64,1}    : Time axis

"""
function ricker(;f::Float64=20.0, n::Int64=41, dt::Float64=0.05)
    # Create the wavelet
    t = timeAxis(dt, 0., n)
    tau = t .- 1/f
    s = (1.0 .- tau.*tau.*f.^2*π.^2).*exp.(-tau.^2*π.^2*f.^2);

    return (s, t)
end

"""

    dampedSinusoid(;A::Float64=1.0, ω::Float64=1.0, ϕ::Float64=0.0, n::Int64=100, dt::Float64=0.001, λ::Float64=2.0)

Generate a damped sinusoid.

# Arguments
- `A::Float64`    : Amplitude of the damped sinusoid
- `n::Int64`    : Number of points
- `dt::Float64`    : Sampling interval
- `ω::Float64`    : Frequency
- `λ::Float64`    : Decay constant
- `ϕ::Float64`    : Phase angle at t=0
- `η::Float64`    : Shift in function maximum

# Output
- `dampedSin::Array{Float64,1}`    : Computed damped sinusoid
- `t::Array{Float64,1}`    : Time axis

"""
function dampedSinusoid(;A::Float64=1.0, ω::Float64=1.0, ϕ::Float64=0.0, η::Float64=0.0, n::Int64=100, dt::Float64=0.001, t0::Float64=0.0, λ::Float64=2.0)
    # generate time axis
    t = timeAxis(dt, t0, n)
    # damped sinusoidal function
    dampedSin = A*exp.(-λ*abs.(t.-η)) .* cos.(ω*t .+ ϕ)

    return (dampedSin, t)
end

"""

    sinc(;A::Float64=1.0, ω::Float64=1.0, ϕ::Float64=0.0, n::Int64=100, dt::Float64=0.001, t0=0.0)

Generate a sinc (cardinal-sin) function

# Arguments
- `A::Float64`    : Amplitude of the damped sinusoid
- `n::Int64`    : Number of points
- `dt::Float64`    : Sampling interval
- `ω::Float64`    : Frequency
- `ϕ::Float64`    : Phase angle at t=0

# Output
- `s::Array{Float64,1}`    : Computed sinc
- `t::Array{Float64,1}`    : Time axis

"""
function sinc(;A::Float64=1.0, ω::Float64=1.0, ϕ::Float64=0.0, n::Int64=100, dt::Float64=0.001, t0::Float64=0.0)
    # generate time axis
    t = timeAxis(dt, t0, n)
    # sinc function
    s = A.*Base.sinc.(ω.*t.+ϕ)

    return (s, t)
end

"""

    chirp(;c::Array{Float64,1}=collect(range(0.15, stop=15.0, length=100)), tp::Array{Float64,1}=collect(range(0.04, stop=4.0, length=100)), mintp::Float64=0.04, maxtp::Float64=4.0, dist::Float64=1000.0, n::Int64=500, dt::Float64=0.002, t0::Float64=0.0)

# Arguments
- `c::Array{Float64,1}`    : phase velocity array
- `tp::Array{Float64,1}`    : period array
- `mintp::Float64`    : minimum period
- `maxtp::Float64`    : maximum period
- `dist::Float64`    : distance
- `n::Int64`    : number of samples in arrays
- `dt::Float64`    : sampling interval
- `t0::Float64`    : start time of time vector
"""
function chirp(;c::Array{Float64,1}=collect(range(0.15, stop=15.0, length=100)), tp::Array{Float64,1}=collect(range(0.04, stop=4.0, length=100)), mintp::Float64=0.04, maxtp::Float64=4.0, dist::Float64=1000.0, n::Int64=500, dt::Float64=0.002, t0::Float64=0.0)
    # generate time axis
    t = timeAxis(dt, t0, n)
    # generate a chirp
    tp_ind = findall(x->(x≤maxtp && x≥mintp), tp)
    sig = [sum(cos.((2π ./ tp[tp_ind]) .* (j .- dist ./ c[tp_ind]))) for j in time]

    return (sig, t)
end

"""

    timeAxis(dt::Float64, t0::Float64, n::Float64)

Create a vector of times given sample frequency, number of points, and start time.

# Arguments
- `dt::Float64`    : Sample interval
- `t0::Int64`    : Start time
- `n::Int64`    : Number of points in the time vector

# Output
- `t::Array{Float64,1}`    : Time axis

"""
function timeAxis(dt::Float64, t0::Float64, n::Int64)
    T = dt * (n-1) # end time
    # create time axis from 0 to end time at dt spacing
    t = collect(0:dt:T) .+ t0

    return t
end
