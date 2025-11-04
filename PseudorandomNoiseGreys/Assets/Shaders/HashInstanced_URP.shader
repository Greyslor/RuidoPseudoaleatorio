Shader "Custom/HashInstanced_URP"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" "RenderType"="Opaque" }

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            // -- Pragmáticos obligatorios --
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ConfigureProcedural
            #pragma target 4.5

            // -- Includes URP básicos --
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // -- Declaraciones --
            StructuredBuffer<uint> _Hashes;
            float4 _Config;

            // -- Función procedural --
            void ConfigureProcedural()
            {
                #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                    uint id = unity_InstanceID;
                    float v = floor(_Config.y * id + 0.00001);
                    float u = id - _Config.x * v;

                    float s = _Config.y;
                    float3 pos = float3(s * (u + 0.5) - 0.5, 0.0, s * (v + 0.5) - 0.5);

                    unity_ObjectToWorld = float4x4(
                        s,0,0,0,
                        0,s,0,0,
                        0,0,s,0,
                        pos.x,pos.y,pos.z,1
                    );
                #endif
            }

            // -- Hash to Color --
            float3 GetHashColor(uint hash)
            {
                float r = (hash & 255) / 255.0;
                float g = ((hash >> 8) & 255) / 255.0;
                float b = ((hash >> 16) & 255) / 255.0;
                return float3(r, g, b);
            }

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 color : COLOR;
            };

            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT;

                #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                    ConfigureProcedural();
                    uint hash = _Hashes[instanceID];
                    OUT.color = GetHashColor(hash);
                #else
                    OUT.color = float3(1, 0, 1);
                #endif

                float4 posWS = mul(unity_ObjectToWorld, float4(IN.positionOS, 1.0));
                OUT.positionHCS = TransformWorldToHClip(posWS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(IN.color, 1);
            }
            ENDHLSL
        }
    }
}
