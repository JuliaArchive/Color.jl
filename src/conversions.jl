# Conversions
# -----------

# no-op conversions
for CV in (RGB, HSV, HSL, XYZ, LAB, LUV, LCHab, LCHuv, DIN99, DIN99o, LMS, RGB24)
    @eval begin
        convert(::Type{$CV}, c::$CV) = c
    end
end


function convert{T,U}(::Type{AlphaColorValue{T}}, c::AlphaColorValue{U})
    AlphaColorValue{T}(convert(T, c.c), c.alpha)
end


# Everything to RGB
# -----------------

function convert(::Type{RGB}, c::HSV)
    h = c.h / 60
    i = floor(h)
    f = h - i
    if int(i) & 1 == 0
        f = 1 - f
    end
    m = c.v * (1 - c.s)
    n = c.v * (1 - c.s * f)
    i = int(i)
    if i == 6 || i == 0; RGB(c.v, n, m)
    elseif i == 1;       RGB(n, c.v, m)
    elseif i == 2;       RGB(m, c.v, n)
    elseif i == 3;       RGB(m, n, c.v)
    elseif i == 4;       RGB(n, m, c.v)
    else;                RGB(c.v, m, n)
    end
end


function convert(::Type{RGB}, c::HSL)
    function qtrans(u::Float64, v::Float64, hue::Float64)
        if     hue > 360; hue -= 360
        elseif hue < 0;   hue += 360
        end

        if     hue < 60;  u + (v - u) * hue / 60
        elseif hue < 180; v
        elseif hue < 240; u + (v - u) * (240 - hue) / 60
        else;             u
        end
    end

    v = c.l <= 0.5 ? c.l * (1 + c.s) : c.l + c.s - (c.l * c.s)
    u = 2 * c.l - v

    if c.s == 0; RGB(c.l, c.l, c.l)
    else;        RGB(qtrans(u, v, c.h + 120),
                     qtrans(u, v, c.h),
                     qtrans(u, v, c.h - 120))
    end
end

const M_XYZ_RGB = [ 3.2404542 -1.5371385 -0.4985314
                   -0.9692660  1.8760108  0.0415560
                    0.0556434 -0.2040259  1.0572252 ]


function correct_gamut(c::RGB)
    RGB(min(1.0, max(0.0, c.r)),
        min(1.0, max(0.0, c.g)),
        min(1.0, max(0.0, c.b)))
end


function srgb_compand(v::Float64)
    v <= 0.0031308 ? 12.92v : 1.055v^(1/2.4) - 0.055
end


function convert(::Type{RGB}, c::XYZ)
    ans = M_XYZ_RGB * [c.x, c.y, c.z]
    correct_gamut(RGB(srgb_compand(ans[1]),
                      srgb_compand(ans[2]),
                      srgb_compand(ans[3])))
end

convert(::Type{RGB}, c::LAB)   = convert(RGB, convert(XYZ, c))
convert(::Type{RGB}, c::LCHab) = convert(RGB, convert(LAB, c))
convert(::Type{RGB}, c::LUV)   = convert(RGB, convert(XYZ, c))
convert(::Type{RGB}, c::LCHuv) = convert(RGB, convert(LUV, c))
convert(::Type{RGB}, c::DIN99) = convert(RGB, convert(XYZ, c))
convert(::Type{RGB}, c::DIN99o) = convert(RGB, convert(XYZ, c))
convert(::Type{RGB}, c::LMS)   = convert(RGB, convert(XYZ, c))

convert(::Type{RGB}, c::RGB24) = RGB((c.color&0x00ff0000>>>16)/255, ((c.color&0x0000ff00)>>>8)/255, (c.color&0x000000ff)/255)


# Everything to HSV
# -----------------

function convert(::Type{HSV}, c::RGB)
    c_min = min([c.r, c.g, c.b])
    c_max = max([c.r, c.g, c.b])
    if c_min == c_max
        return HSV(0.0, 0.0, c_max)
    end

    if c_min == c.r
        f = c.g - c.b
        i = 3.
    elseif c_min == c.g
        f = c.b - c.r
        i = 5.
    else
        f = c.r - c.g
        i = 1.
    end

    HSV(60 * (i - f / (c_max - c_min)),
        (c_max - c_min) / c_max,
        c_max)
end


convert(::Type{HSV}, c::ColorValue) = convert(HSV, convert(RGB, c))


# Everything to HSL
# -----------------

function convert(::Type{HSL}, c::RGB)
    c_min = min(c.r, c.g, c.b)
    c_max = max(c.r, c.g, c.b)
    l = (c_max - c_min) / 2

    if c_max == c_min
        return HSL(0.0, 0.0, l)
    end

    if l < 0.5; s = (c_max - c_min) / (c_max + c_min)
    else;       s = (c_max - c_min) / (2.0 - c_max - c_min)
    end

    if c_max == c.r
        h = (c.g - c.b) / (c_max - c_min)
    elseif c_max == c.g
        h = 2.0 + (c.b - c.r) / (c_max - c_min)
    else
        h = 4.0 + (c.r - c.g) / (c_max - c_min)
    end

    h *= 60
    if h < 0
        h += 360
    elseif h > 360
        h -= 360
    end

    HSL(h,s,l)
end


convert(::Type{HSL}, c::ColorValue) = convert(HSL, convert(RGB, c))


# Everything to XYZ
# -----------------

function invert_rgb_compand(v::Float64)
    v <= 0.04045 ? v/12.92 : ((v+0.055) /1.055)^2.4
end


const M_RGB_XYZ =
    [ 0.4124564  0.3575761  0.1804375
      0.2126729  0.7151522  0.0721750
      0.0193339  0.1191920  0.9503041 ]


function convert(::Type{XYZ}, c::RGB)
    v = [invert_rgb_compand(c.r),
         invert_rgb_compand(c.g),
         invert_rgb_compand(c.b)]
    ans = M_RGB_XYZ * v
    XYZ(ans[1], ans[2], ans[3])
end


convert(::Type{XYZ}, c::HSV) = convert(XYZ, convert(RGB, c))
convert(::Type{XYZ}, c::HSL) = convert(XYZ, convert(RGB, c))


const xyz_epsilon = 216. / 24389.
const xyz_kappa   = 24389. / 27.


function convert(::Type{XYZ}, c::LAB, wp::XYZ)
    fy = (c.l + 16) / 116
    fx = c.a / 500 + fy
    fz = fy - c.b / 200

    fx3 = fx^3
    fz3 = fz^3

    x = fx3 > xyz_epsilon ? fx3 : (116fx - 16) / xyz_kappa
    y = c.l > xyz_kappa * xyz_epsilon ? ((c. l+ 16) / 116)^3 : c.l / xyz_kappa
    z = fz3 > xyz_epsilon ? fz3 : (116fz - 16) / xyz_kappa

    XYZ(x*wp.x, y*wp.y, z*wp.z)
end


convert(::Type{XYZ}, c::LAB)   = convert(XYZ, c, WP_DEFAULT)
convert(::Type{XYZ}, c::LCHab) = convert(XYZ, convert(LAB, c))
convert(::Type{XYZ}, c::DIN99) = convert(XYZ, convert(LAB, c))
convert(::Type{XYZ}, c::DIN99o) = convert(XYZ, convert(LAB, c))


function xyz_to_uv(c::XYZ)
    d = c.x + 15c.y + 3c.z
    u = (4. * c.x) / d
    v = (9. * c.y) / d
    return (u,v)
end


function convert(::Type{XYZ}, c::LUV, wp::XYZ)
    (u_wp, v_wp) = xyz_to_uv(wp)

    a = (52 * c.l / (c.u + 13 * c.l * u_wp) - 1) / 3
    y = c.l > xyz_kappa * xyz_epsilon ? ((c.l + 16) / 116)^3 : c.l / xyz_kappa
    b = -5y
    d = y * (39 * c.l / (c.v + 13 * c.l * v_wp) - 5)
    x = (d - b) / (a + (1./3.))
    z = a * x + b

    XYZ(x, y, z)
end


convert(::Type{XYZ}, c::LUV)   = convert(XYZ, c, WP_DEFAULT)
convert(::Type{XYZ}, c::LCHuv) = convert(XYZ, convert(LUV, c))


function convert(::Type{XYZ}, c::LMS)
    ans = CAT02_INV * [c.l, c.m, c.s]
    XYZ(ans[1], ans[2], ans[3])
end


# Everything to LAB
# -----------------

convert(::Type{LAB}, c::RGB) = convert(LAB, convert(XYZ, c))
convert(::Type{LAB}, c::HSV) = convert(LAB, convert(RGB, c))
convert(::Type{LAB}, c::HSL) = convert(LAB, convert(RGB, c))


function convert(::Type{LAB}, c::XYZ, wp::XYZ)
    function f(v::Float64)
        v > xyz_epsilon ? cbrt(v) : (xyz_kappa * v + 16) / 116
    end

    fx, fy, fz = f(c.x / wp.x), f(c.y / wp.y), f(c.z / wp.z)
    LAB(116fy - 16, 500(fx - fy), 200(fy - fz))
end


convert(::Type{LAB}, c::XYZ) = convert(LAB, c, WP_DEFAULT)


function convert(::Type{LAB}, c::LCHab)
    hr = deg2rad(c.h)
    LAB(c.l, c.c * cos(hr), c.c * sin(hr))
end


function convert(::Type{LAB}, c::DIN99)

    # FIXME: right now we assume the adjustment parameters are always 1.
    kch = 1
    ke = 1

    # Calculate Chroma (C99) in the DIN99 space
    cc = sqrt(c.a^2 + c.b^2)

    # NOTE: This is calculated in degrees, against the standard, to save
    # computation steps later.
    if (c.a > 0 && c.b >= 0)
        h = atand(c.b/c.a)
    elseif (c.a == 0 && c.b > 0)
        h = 90
    elseif (c.a < 0)
        h = 180+atand(c.b/c.a)
    elseif (c.a == 0 && c.b < 0)
        h = 270
    elseif (c.a > 0 && c.b <= 0)
        h = 360 + atand(c.b/c.a)
    else
        h = 0
    end

    # Temporary variable for chroma
    g = (e^(0.045*cc*kch*ke)-1)/0.045

    # Temporary redness
    ee = g*cosd(h)

    # Temporary yellowness
    f = g*sind(h)

    # CIELAB a*b*
    # FIXME: hard-code the constants.
    ciea = ee*cosd(16) - (f/0.7)*sind(16)
    cieb = ee*sind(16) + (f/0.7)*cosd(16)

    # CIELAB L*
    ciel = (e^(c.l*ke/105.51)-1)/0.0158

    LAB(ciel, ciea, cieb)
end


function convert(::Type{LAB}, c::DIN99o)

    # FIXME: right now we assume the adjustment parameters are always 1.
    kch = 1
    ke = 1

    # Calculate Chroma (C99) in the DIN99 space
    cc = sqrt(c.a^2 + c.b^2)

    # NOTE: This is calculated in degrees, against the standard, to save
    # computation steps later.
    if (c.a > 0 && c.b >= 0)
        h = atand(c.b/c.a)
    elseif (c.a == 0 && c.b > 0)
        h = 90
    elseif (c.a < 0)
        h = 180+atand(c.b/c.a)
    elseif (c.a == 0 && c.b < 0)
        h = 270
    elseif (c.a > 0 && c.b <= 0)
        h = 360 + atand(c.b/c.a)
    else
        h = 0
    end

    # Temporary variable for chroma
    g = (e^(0.0435*cc*kch*ke)-1)/0.0435

    # Temporary redness
    ee = g*cosd(h)

    # Temporary yellowness
    f = g*sind(h)

    # CIELAB a*b*
    # FIXME: hard-code the constants.
    ciea = ee*cosd(83) - (f/0.83)*sind(26)
    cieb = ee*sind(83) + (f/0.83)*cosd(26)

    # CIELAB L*
    ciel = (e^(c.l*ke/303.67)-1)/0.0039

    LAB(ciel, ciea, cieb)
end


convert(::Type{LAB}, c::ColorValue) = convert(LAB, convert(XYZ, c))


# Everything to LUV
# -----------------

convert(::Type{LUV}, c::RGB) = convert(LUV, convert(XYZ, c))
convert(::Type{LUV}, c::HSV) = convert(LUV, convert(RGB, c))
convert(::Type{LUV}, c::HSL) = convert(LUV, convert(RGB, c))


function convert(::Type{LUV}, c::XYZ, wp::XYZ)
    (u_wp, v_wp) = xyz_to_uv(wp)
    (u_, v_) = xyz_to_uv(c)

    y = c.y / wp.y

    l = y > xyz_epsilon ? 116 * cbrt(y) - 16 : xyz_kappa * y
    u = 13 * l * (u_ - u_wp)
    v = 13 * l * (v_ - v_wp)

    LUV(l, u, v)
end


convert(::Type{LUV}, c::XYZ) = convert(LUV, c, WP_DEFAULT)


function convert(::Type{LUV}, c::LCHuv)
    hr = deg2rad(c.h)
    LUV(c.l, c.c * cos(hr), c.c * sin(hr))
end


convert(::Type{LUV}, c::ColorValue) = convert(LUV, convert(XYZ, c))


# Everything to LCHuv
# -------------------

function convert(::Type{LCHuv}, c::LUV)
    h = rad2deg(atan2(c.v, c.u))
    while h > 360; h -= 360; end
    while h < 0;   h += 360; end
    LCHuv(c.l, sqrt(c.u^2 + c.v^2), h)
end


convert(::Type{LCHuv}, c::ColorValue) = convert(LCHuv, convert(LUV, c))


# Everything to LCHab
# -------------------

function convert(::Type{LCHab}, c::LAB)
    h = rad2deg(atan2(c.b, c.a))
    while h > 360; h -= 360; end
    while h < 0;   h += 360; end
    LCHab(c.l, sqrt(c.a^2 + c.b^2), h)
end


convert(::Type{LCHab}, c::ColorValue) = convert(LCHab, convert(LAB, c))


# Everything to DIN99
# -------------------

function convert(::Type{DIN99}, c::LAB)
    # FIXME: right now we assume the adjustment parameters are always 1.
    kch = 1
    ke = 1

    # Calculate DIN99 L
    l99 = (1/ke)*105.51*log(1+0.0158*c.l)

    # Temporary value for redness and yellowness
    # FIXME: hard-code the constants
    ee = c.a*cosd(16) + c.b*sind(16)
    f = -0.7*c.a*sind(16) + 0.7*c.b*cosd(16)

    # Temporary value for chroma
    g = sqrt(ee^2 + f^2)

    # Hue angle
    # Calculated in degrees, against the specification.
    if (ee > 0 && f >= 0)
        h = atand(f/ee)
    elseif (ee == 0 && f > 0)
        h = 90
    elseif (ee < 0)
        h = 180+atand(f/ee)
    elseif (ee == 0 && f < 0)
        h = 270
    elseif (ee > 0 && f <= 0)
        h = 360 + atand(f/ee)
    else
        h = 0
    end

    # DIN99 chroma
    cc = log(1+0.045*g)/(0.045*kch*ke)

    # DIN99 chromaticities
    a99, b99 = cc*cosd(h), cc*sind(h)

    DIN99(l99, a99, b99)

end


convert(::Type{DIN99}, c::ColorValue) = convert(DIN99, convert(LAB, c))

# Everything to DIN99o
# -------------------

function convert(::Type{DIN99o}, c::LAB)
    # FIXME: right now we assume the adjustment parameters are always 1.
    kch = 1
    ke = 1

    # Calculate DIN99o L
    l99o = 105.51/ke*log(1+0.0039*c.l)

    # Temporary value for redness and yellowness
    # FIXME: hard-code the constants
    eo = c.a*cosd(26) + c.b*sind(26)
    fo = -0.83*c.a*sind(26) + 0.83*c.b*cosd(26)

    # Temporary value for chroma
    go = sqrt(eo^2 + fo^2)
    
    # Hue angle
    # Calculated in degrees, against the specification.
    if (eo > 0 && fo >= 0)
        h = atand(fo/eo)
    elseif (eo == 0 && fo > 0)
        h = 90
    elseif (eo < 0)
        h = 180+atand(fo/eo)
    elseif (eo == 0 && fo < 0)
        h = 270
    elseif (eo > 0 && fo <= 0)
        h = 360 + atand(fo/eo)
    else
        h = 0
    end

    # DIN99o chroma
    cc = log(1+0.075*go)/(0.0435*kch*ke)

    # DIN99o chromaticities
    a99, b99 = cc*cosd(h), cc*sind(h)

    DIN99o(l99, a99, b99)

end


convert(::Type{DIN99o}, c::ColorValue) = convert(DIN99o, convert(LAB, c))

# Everything to LMS
# -----------------

# Chromatic adaptation from CIECAM97s
const CAT97s = [ 0.8562  0.3372 -0.1934
                -0.8360  1.8327  0.0033
                 0.0357 -0.0469  1.0112 ]

const CAT97s_INV = inv(CAT97s)

# Chromatic adaptation from CIECAM02
const CAT02 = [ 0.7328 0.4296 -0.1624
               -0.7036 1.6975  0.0061
                0.0030 0.0136  0.9834 ]

const CAT02_INV = inv(CAT02)


function convert(::Type{LMS}, c::XYZ)
    ans = CAT02 * [c.x, c.y, c.z]
    LMS(ans[1], ans[2], ans[3])
end


convert(::Type{LMS}, c::ColorValue) = convert(LMS, convert(XYZ, c))


# Everything to RGB24
# -------------------

convert(::Type{RGB24}, c::RGB) = RGB24(iround(Uint32, 255*c.r)<<16 +
    iround(Uint32, 255*c.g)<<8 + iround(Uint32, 255*c.b))


convert(::Type{RGB24}, c::ColorValue) = convert(RGB24, convert(RGB, c))


# To Uint32
# ----------------

convert(::Type{Uint32}, c::RGB24) = c.color


convert(::Type{Uint32}, ac::RGBA32) = convert(Uint32, ac.c) | iround(Uint32, 255*ac.alpha)<<24
