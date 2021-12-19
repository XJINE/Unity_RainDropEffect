Shader "ImageEffect/RainDrop"
{
    Properties
    {
        _MainTex        ("Texture",         2D)              = "white" {}
        _Scale          ("Scale",           Float)           = 5
        _Aspect         ("Aspect",          Float)           = 1
        _DropSize       ("DropSize",        Range(  0, 0.5)) = 0.15
        _DropAspect     ("DropAspect",      Range(  0,  10)) = 3
        _DropSpeed      ("DropSpeed",       Range(-10,  10)) = 0.5
        _DropSpeedGap   ("DropSpeedGap",    Range(  0,  30)) = 10
        _DropWigglePower("DropWigglePower", Range(  0,  30)) = 10
        _DropDistortion ("DropDistortion",  Range( -5,   5)) = -5
        _DropComplex    ("DropComplex",     Range(  0,   5)) = 2
        _FoggyBlur      ("FoggyBlur",       Range(  0,  10)) = 5
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM

            #include "UnityCG.cginc"
            #pragma  vertex vert_img
            #pragma  fragment frag

            sampler2D _MainTex;

            float _Scale;
            float _Aspect;
            float _DropSize;
            float _DropAspect;
            float _DropSpeed;
            float _DropSpeedGap;
            float _DropWigglePower;
            float _DropDistortion;
            int   _DropComplex;
            float _FoggyBlur;

            float random(float2 seeds)
            {
                return frac(sin(dot(seeds, float2(12.9898, 78.233))) * 43758.5453);
            }

            float3 DropLayer(float2 iUV, float t)
            {
                float2 uv    = iUV * _Scale;
                       uv.x *= _Aspect;
                       uv.y += random(floor(uv.x) + 0.1); // Offset each column.
                       uv.y += t * _DropSpeed;            // Y-direction scroll.

                // -0.5 means set the origin into the center of the Grid.
                float2 gridUV = frac (uv) - 0.5;
                float2 gridID = floor(uv);

                // DEBUG:
                // return float4(gridUV.xy, 0, 1);

                // Make some time-gap into each Grid.
                t += random(gridID * gridID) * _DropSpeedGap;

                // Keep wiggleX range (-0.4 ~ 0.4).
                float wigglePow = iUV.y * random(gridID.xx) * _DropWigglePower;
                float wiggleX   = sin(3 * wigglePow) * pow(sin(wigglePow), 6) * random(gridID.yy) * 0.5;

                // DEBUG:
                // wiggleX = 0;

                // Keep x, y value inside gridUV coord (-1, 1).
                // Its also needs to care the drop size.

                // Rnd(0 ~ 1) - 0.5 means start from center.
                float x = random(gridID.yx) - 0.5;
                      x = clamp(x + wiggleX, -0.35, 0.35);
                float y = -sin(t + sin(t + sin(t) * 0.5)) * 0.3;

                // Stretch drop shape Y.
                y -= gridUV.y * gridUV.y * 0.8;
                y = clamp(y, -0.35, 0.35);

                float2 dropPos    = gridUV - float2(x, y);
                       dropPos.x *= _DropAspect;

                float  dropSizeRnd = random(gridID.xy);
                float2 dropSize    = dropSizeRnd < 0.25 ? 1 : dropSizeRnd * _DropSize;
                       dropSize.y  = dropSizeRnd < 0.25 ? 1 : dropSize.x * 0.25;

                // dropSize.y must be smaller than x
                // Because of we needs reversed smoothstep value to make white drop.
                float drop = smoothstep(dropSize.x, dropSize.y, length(dropPos));

                // Show trails in higher than the dropPos.y. -0.05 means a little offset.
                float fogTrail  = smoothstep(     -0.05,       0.05,      dropPos.y);
                      fogTrail *= smoothstep(       0.5,          y,       gridUV.y); // Fade out trail-Y.
                      fogTrail *= smoothstep(dropSize.x, dropSize.y, abs(dropPos.x)); // Fade out trail-X.

                return float3(drop * dropPos, fogTrail);
            }

            fixed4 frag(v2f_img i) : SV_Target
            {
                float t = fmod(_Time.y, 72000);

                float3 drops  = DropLayer(i.uv, t);

                for(int c = 1; c <= _DropComplex; c++)
                {
                    drops += DropLayer(i.uv + c * 0.123, t + c * 0.456);
                }

                float  blur  = _FoggyBlur * (1 - drops.z);
                float4 color = tex2Dlod(_MainTex, float4(i.uv + drops.xy * _DropDistortion, 0, blur));

                return color;
            }

            ENDCG
        }
    }
}