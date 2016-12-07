
# following
#  https://www.mrao.cam.ac.uk/~dag/CUBEHELIX/
#
# published in 
#  Green, D. A., 2011, `A colour scheme for the display of astronomical intensity images', Bulletin of the Astronomical Society of India, 39, 289.
#    (2011BASI...39..289G at ADS.) 

import Color: RGB

# parameters: N number of entries in result colormap (btw: Array(RGB{Float64},N))
#  rotations: rotations -> added term
#  start: startpoint in H -> 0.0 -> Red
#  hue: saturation of hue -> 0.0 -> grayscale only, >1.0 -> clipping in some areas
#  gamma: gamma factor 

function cubehelix(N::Integer; rotations::Real=-1.5,start::Real=0.0,hue::Real=1.0,gamma::Real=1.0)
    colormap = Array(RGB{Float64},N)
    fract_all = linspace(0,1,N)
    coeff_cos = [+0.14861, -0.29227, +1.97294]
    coeff_sin = [+1.78277, -0.90649, 0.0]
    c = zeros(3)
    for (i,fract) in enumerate(fract_all)
        c[1]=c[2]=c[3]=0

        angle = 2*pi*(((start/3.0)+1.0+rotations)*fract)
        fract = fract ^ gamma
        amp = hue*fract*(1-fract)/2.0
        for j in 1:3
            c[j] = clamp(
                fract + amp * ((coeff_cos[j]*cos(angle)) + (coeff_sin[j] * sin(angle))),
                0.0,1.0)
        end
        colormap[i] = RGB{Float64}(c[1],c[2],c[3])
    end
    colormap
end
