## integer functions ##

abs(x::Unsigned ) = x
abs(x::Int8 ) = (y=x>>7;  boxsi8 (add_int(unbox8 (x),unbox8 (y)))$y)
abs(x::Int16) = (y=x>>15; boxsi16(add_int(unbox16(x),unbox16(y)))$y)
abs(x::Int32) = (y=x>>31; boxsi32(add_int(unbox32(x),unbox32(y)))$y)
abs(x::Int64) = (y=x>>63; boxsi64(add_int(unbox64(x),unbox64(y)))$y)

isodd(n::Integer) = bool(rem(n,2))
iseven(n::Integer) = !isodd(n)

sign{T<:Integer}(x::T) = convert(T,(x > 0)-(x < 0))
sign{T<:Unsigned}(x::T) = convert(T,(x > 0))

signbit(x::Unsigned) = 0
signbit(x::Int8 ) = int(x>>>7)
signbit(x::Int16) = int(x>>>15)
signbit(x::Int32) = int(x>>>31)
signbit(x::Int64) = int(x>>>63)

copysign(x::Int8 , y::Int8 ) = (t=(x$y)>>7;  boxsi8 (add_int(unbox8 (x),unbox8 (t)))$t)
copysign(x::Int16, y::Int16) = (t=(x$y)>>15; boxsi16(add_int(unbox16(x),unbox16(t)))$t)
copysign(x::Int32, y::Int32) = (t=(x$y)>>31; boxsi32(add_int(unbox32(x),unbox32(t)))$t)
copysign(x::Int64, y::Int64) = (t=(x$y)>>63; boxsi64(add_int(unbox64(x),unbox64(t)))$t)

copysign(x::Signed, y::Real)    = copysign(x, -oftype(x,signbit(y)))
copysign(x::Signed, y::Float32) = copysign(x, reinterpret(Int32,y))
copysign(x::Signed, y::Float64) = copysign(x, reinterpret(Int64,y))

## number-theoretic functions ##

function gcd{T<:Integer}(a::T, b::T)
    neg = a < 0
    while b != 0
        t = b
        b = rem(a, b)
        a = t
    end
    g = abs(a)
    neg ? -g : g
end
lcm{T<:Integer}(a::T, b::T) = div(a*b, gcd(b,a))

gcd(a::Integer) = a
lcm(a::Integer) = a
gcd(a::Integer, b::Integer) = gcd(promote(a,b)...)
lcm(a::Integer, b::Integer) = lcm(promote(a,b)...)
gcd(a::Integer, b::Integer...) = gcd(a, gcd(b...))
lcm(a::Integer, b::Integer...) = lcm(a, lcm(b...))

# return (gcd(a,b),x,y) such that ax+by == gcd(a,b)
function gcdx(a, b)
    if b == 0
        (a, 1, 0)
    else
        m = rem(a, b)
        k = div((a-m), b)
        (g, x, y) = gcdx(b, m)
        (g, y, x-k*y)
    end
end

# multiplicative inverse of x mod m, error if none
function invmod(n, m)
    g, x, y = gcdx(n, m)
    g != 1 ? error("no inverse exists") : (x < 0 ? m + x : x)
end

# ^ for any x supporting *
function power_by_squaring(x, p::Integer)
    if p == 1
        return x
    elseif p == 0
        return one(x)
    elseif p < 0
        return inv(x^(-p))
    elseif p == 2
        return x*x
    end
    t = 1
    while t <= p
        t *= 2
    end
    t = div(t,2)
    p -= t
    a = x
    while true
        t = div(t,2)
        if t > 0
            x = x*x
        else
            break
        end

        if p >= t
            x = x*a
            p -= t
        end
    end
    return x
end

^{T<:Integer}(x::T, p::T) = power_by_squaring(x,p)
^(x::Number, p::Integer)  = power_by_squaring(x,p)
^(x, p::Integer)          = power_by_squaring(x,p)

# x^p mod m
function powermod(x::Integer, p::Integer, m::Integer)
    if p == 0
        return one(x)
    elseif p < 0
        error("powermod: exponent must be >= 0, got $p")
    end
    t = 1
    while t <= p
        t *= 2
    end
    t = div(t,2)
    r = 1
    while true
        if p >= t
            r = mod(r*x, m)
            p -= t
        end
        t = div(t,2)
        if t > 0
            r = mod(r*r, m)
        else
            break
        end
    end
    return r
end

# smallest power of 2 >= i
nextpow2(x::Unsigned) = one(x)<<((sizeof(x)<<3)-leading_zeros(x-1))
nextpow2(x::Integer) = oftype(x,x < 0 ? -nextpow2(unsigned(-x)) : nextpow2(unsigned(x)))

# decimal digits in an unsigned integer
global const _jl_powers_of_ten = [
    0x0000000000000001, 0x000000000000000a, 0x0000000000000064, 0x00000000000003e8,
    0x0000000000002710, 0x00000000000186a0, 0x00000000000f4240, 0x0000000000989680,
    0x0000000005f5e100, 0x000000003b9aca00, 0x00000002540be400, 0x000000174876e800,
    0x000000e8d4a51000, 0x000009184e72a000, 0x00005af3107a4000, 0x00038d7ea4c68000,
    0x002386f26fc10000, 0x016345785d8a0000, 0x0de0b6b3a7640000, 0x8ac7230489e80000,
]
function ndigits0z(x::Unsigned)
    lz = (sizeof(x)<<3)-leading_zeros(x)
    nd = (1233*lz)>>12+1
    nd -= x < _jl_powers_of_ten[nd]
end
ndigits0z(x::Integer) = ndigits0z(unsigned(abs(x)))
# TODO: custom versions for each unsigned type?

ndigits(x::Unsigned) = x==0 ? 1 : ndigits0z(x)
ndigits(x::Integer) = ndigits(unsigned(abs(x)))

## integer to string functions ##

macro _jl_int_stringifier(sym)
    quote
        ($sym)(x::Unsigned, p::Int) = ($sym)(x,p,false)
        ($sym)(x::Unsigned)         = ($sym)(x,0,false)
        ($sym)(x::Integer, p::Int)  = ($sym)(unsigned(abs(x)),p,x<0)
        ($sym)(x::Integer)          = ($sym)(unsigned(abs(x)),0,x<0)
    end
end

function bin(x::Unsigned, pad::Int, neg::Bool)
    if x == 0; return "0"; end
    i = neg + max(pad,sizeof(x)<<3-leading_zeros(x))
    a = Array(Uint8,i)
    while i > neg
        a[i] = '0'+(x&0x1)
        x >>= 1
        i -= 1
    end
    if neg; a[1]='-'; end
    ASCIIString(a)
end

function oct(x::Unsigned, pad::Int, neg::Bool)
    if x == 0; return "0"; end
    i = neg + max(pad,div((sizeof(x)<<3)-leading_zeros(x)+2,3))
    a = Array(Uint8,i)
    while i > neg
        a[i] = '0'+(x&0x7)
        x >>= 3
        i -= 1
    end
    if neg; a[1]='-'; end
    ASCIIString(a)
end

function dec(x::Unsigned, pad::Int, neg::Bool)
    if x == 0; return "0"; end
    i = neg + max(pad,ndigits0z(x))
    a = Array(Uint8,i)
    while i > neg
        a[i] = '0'+mod(x,10)
        x = div(x,10)
        i -= 1
    end
    if neg; a[1]='-'; end
    ASCIIString(a)
end

function hex(x::Unsigned, pad::Int, neg::Bool)
    if x == 0; return "0"; end
    i = neg + max(pad,(sizeof(x)<<1)-(leading_zeros(x)>>2))
    a = Array(Uint8,i)
    while i > neg
        a[i] = _jl_hex_symbols[(x&0xf)+1]
        x >>= 4
        i -= 1
    end
    if neg; a[1]='-'; end
    ASCIIString(a)
end

@_jl_int_stringifier bin
@_jl_int_stringifier oct
@_jl_int_stringifier dec
@_jl_int_stringifier hex

bits(x::Union(Bool,Int8,Uint8))           = bin(reinterpret(Uint8 ,x),  8)
bits(x::Union(Int16,Uint16))              = bin(reinterpret(Uint16,x), 16)
bits(x::Union(Char,Int32,Uint32,Float32)) = bin(reinterpret(Uint32,x), 32)
bits(x::Union(Int64,Uint64,Float64))      = bin(reinterpret(Uint64,x), 64)
