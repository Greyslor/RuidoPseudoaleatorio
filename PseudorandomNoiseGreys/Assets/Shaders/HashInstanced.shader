Shader "Custom/HashInstanced" {
    Properties {
        _Color ("Base Color", Color) = (1,1,1,1)
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        Pass {
            Tags { "LightMode"="UniversalForward" }

            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            StructuredBuffer<uint> _Hashes;
            float4 _Config;

            float3 GetHashColor(uint hash) {
                float r = (hash & 255) / 255.0;
                float g = ((hash >> 8) & 255) / 255.0;
                float b = ((hash >> 16) & 255) / 255.0;
                return float3(r,g,b);
            }

            float4x4 BuildMatrix(uint id, float4 config) {
                float v = floor(config.y * id + 0.00001);
                float u = id - config.x * v;
                float3 pos = float3(config.y * (u + 0.5) - 0.5, 0.0, config.y * (v + 0.5) - 0.5);
                float s = config.y;
                return float4x4(
                    s,0,0,0,
                    0,s,0,0,
                    0,0,s,0,
                    pos.x,pos.y,pos.z,1
                );
            }

            struct Attributes {
                float3 positionOS : POSITION;
            };

            struct Varyings {
                float4 positionHCS : SV_POSITION;
                float3 color : COLOR;
            };

            Varyings vert(Attributes IN, uint id : SV_InstanceID) {
                Varyings OUT;
                float4x4 model = BuildMatrix(id, _Config);
                uint hash = _Hashes[id];
                OUT.color = GetHashColor(hash);
                float4 posWS = mul(model, float4(IN.positionOS, 1.0));
                OUT.positionHCS = TransformWorldToHClip(posWS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target {
                return half4(IN.color, 1);
            }
            ENDHLSL
        }
    }
}
