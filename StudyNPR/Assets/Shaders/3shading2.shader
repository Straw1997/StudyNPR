// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Scarecrow/3shading2"
{
    Properties
    {
        [Header(Texture)]
        _MainTex ("Main Tex", 2D) = "white" { }
        _ILMTex ("ILM Tex", 2D) = "white" { }
        _SSSTex ("SSS Tex", 2D) = "white" { }
        
        [Header(Shadow)]
        _ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.5
        _ShadowRange ("Shadow Range", Range(-1.0, 1.0)) = 0
        
        [Header(Spaceular)]
        _SpecularIntensity ("Specular Intensity", Range(0.0, 100)) = 0.5
        _Gloss ("Gloss", float) = 10
        _SpecularRange ("Specular Range", Range(0, 1)) = 0.5
        
        [Header(Line)]
        _OutlineWidth ("Outline Width", Range(0.0, 0.08)) = 0
        _OutlineColor ("Outline Color", color) = (0, 0, 0, 1)
        _InnerStrokeIntensity ("Inner Stroke Intensity", Range(0.0, 3)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Pass
        {
            CGPROGRAM
            
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            struct a2v
            {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
                float2 uv: TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos: SV_POSITION;
                float3 normal: TEXCOORD0;
                float2 uv: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
            };
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _ILMTex;
            sampler2D _SSSTex;
            fixed _ShadowIntensity;
            fixed _ShadowRange;
            float _SpecularIntensity;
            float _Gloss;
            fixed _SpecularRange;
            fixed _InnerStrokeIntensity;
            
            
            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                fixed3 normal = normalize(i.normal);
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + lightDir);
                
                fixed NdotL = dot(normal, lightDir);
                fixed NdotH = max(0, dot(normal, halfDir));
                
                //亮部颜色
                fixed4 brightCol = tex2D(_MainTex, i.uv);
                fixed4 ilmTex = tex2D(_ILMTex, i.uv);
                fixed4 sssTex = tex2D(_SSSTex, i.uv);
                
                //阴影颜色
                // fixed4 shadowCol = brightCol * (1 - _ShadowIntensity);
                fixed4 shadowCol = brightCol * sssTex;
                //阴影阈值
                fixed shadowThreshold = saturate(1 - ilmTex.g + _ShadowRange);
                //内描边
                fixed innerStroke = lerp(1, ilmTex.a, _InnerStrokeIntensity);
                
                //漫反射
                fixed shadowContrast = step(shadowThreshold, NdotL);
                fixed4 finalCol = lerp(shadowCol, brightCol, shadowContrast);
                //高光
                finalCol += brightCol * _SpecularIntensity * step((1 - ilmTex.b * _SpecularRange), pow(NdotH, _Gloss)) * ilmTex.r * shadowContrast;
                finalCol *= _LightColor0 * innerStroke;
                
                // return shadowCol;
                return fixed4(finalCol.rgb, 1);
            }
            ENDCG
            
        }
        
        pass
        {
            CULL Front
            CGPROGRAM
            
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            struct a2v
            {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
            };
            struct v2f
            {
                float4 pos: SV_POSITION;
            };
            
            fixed _OutlineWidth;
            fixed4 _OutlineColor;
            
            v2f vert(a2v v)
            {
                v2f o;
                // float3 viewPos = UnityObjectToViewPos(v.vertex);
                // float3 viewNormal = mul(UNITY_MATRIX_IT_MV, v.normal);
                // viewNormal.z = -0.5f;
                // viewPos += normalize(viewNormal) * _OutlineWidth;
                // o.pos = UnityViewToClipPos(viewPos);
                
                float4 pos = UnityObjectToClipPos(v.vertex);
                float3 viewNormal = mul(UNITY_MATRIX_IT_MV, v.normal);
                float3 proNormal = normalize(TransformViewToProjection(viewNormal)) * pos.w;
                float4 nearUpperRight = mul(unity_CameraInvProjection, _ProjectionParams.y * float4(1, 1, -1, 1));
                proNormal.x *= abs(nearUpperRight.y / nearUpperRight.x);
                pos.xy += proNormal.xy * _OutlineWidth * 0.1f;
                o.pos = pos;
                
                return o;
            }
            fixed4 frag(v2f i): SV_Target
            {
                return _OutlineColor;
            }
            
            ENDCG
            
        }
    }
}
