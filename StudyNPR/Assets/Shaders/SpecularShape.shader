Shader "Scarecrow/SpecularShape"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" { }
        _Color ("Color", Color) = (1, 1, 1, 1)
        _SpecularColor ("SpecularColor", Color) = (1, 1, 1, 1)
        _SpecularTranslate ("SpecularTranslate", vector) = (0, 0, 0, 0)
        _SpecularRotation ("SpecularRotation", vector) = (0, 0, 0, 0)
        _SpecularScale ("SpecluarScale", vector) = (0, 0, 0.7, 0)
        _SpecularSplit ("SpecluarSplit", vector) = (0, 0, 0, 0)
        _SpecularSquare ("SpecularSquare", vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        LOD 100
        
        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            struct appdata
            {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
                float4 tangent: TANGENT;
                float2 uv: TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos: SV_POSITION;
                float2 uv: TEXCOORD0;
                float4 tToW0: TEXCOORD1;
                float4 tToW1: TEXCOORD2;
                float4 tToW2: TEXCOORD3;
            };
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            fixed4 _SpecularColor;
            float2 _SpecularTranslate;
            float3 _SpecularRotation;
            float3 _SpecularScale;
            float2 _SpecularSplit;
            float2 _SpecularSquare;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                o.tToW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.tToW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.tToW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                
                
                
                //世界空间下 切线、副法线、法线、位置、灯光方向、观察方向
                fixed3 tangent = normalize(float3(i.tToW0.x, i.tToW1.x, i.tToW2.x));
                fixed3 binormal = normalize(float3(i.tToW0.y, i.tToW1.y, i.tToW2.y));
                fixed3 normal = normalize(float3(i.tToW0.z, i.tToW1.z, i.tToW2.z));
                float3 worldPos = float3(i.tToW0.w, i.tToW1.w, i.tToW2.w);
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                
                //漫反射
                fixed3 diffuse = col.rgb * _Color.rgb * dot(lightDir, normal);
                
                //世界空间下的半角矢量、切线空间下的半角矢量、法线
                fixed3 halfDir = normalize(lightDir + viewDir);
                fixed3 tangentHalfDir = normalize(fixed3(dot(tangent, halfDir), dot(binormal, halfDir), dot(normal, halfDir)));
                fixed3 tangentNormal = normalize(fixed3(dot(tangent, normal), dot(binormal, normal), dot(normal, normal)));
                
                //变换半角矢量，改变高光形状
                //平移
                tangentHalfDir += float3(_SpecularTranslate.xy, 0);
                tangentHalfDir = normalize(tangentHalfDir);
                
                //旋转
                float3 rotation = float3(radians(_SpecularRotation.x), radians(_SpecularRotation.y), radians(_SpecularRotation.z));
                //构建旋转矩阵
                float3x3 rotationX = float3x3(1, 0, 0,
                0, cos(rotation.x), -sin(rotation.x),
                0, sin(rotation.x), cos(rotation.x));
                float3x3 rotationY = float3x3(cos(rotation.y), 0, sin(rotation.y),
                0, 1, 0,
                - sin(rotation.y), 0, cos(rotation.y));
                float3x3 rotationZ = float3x3(cos(rotation.z), -sin(rotation.z), 0,
                sin(rotation.z), cos(rotation.z), 0,
                0, 0, 1);
                tangentHalfDir = mul(rotationZ, mul(rotationY, mul(rotationX, tangentHalfDir)));
                
                //缩放
                tangentHalfDir = normalize(tangentHalfDir - _SpecularScale.x * tangentHalfDir.x * fixed3(1, 0, 0));
                tangentHalfDir = normalize(tangentHalfDir - _SpecularScale.y * tangentHalfDir.y * fixed3(0, 1, 0));
                
                //分离
                fixed2 signHalf = sign(tangentHalfDir.xy);
                tangentHalfDir = normalize(tangentHalfDir - fixed3(_SpecularSplit.xy * signHalf, 0));
                
                //方化
                fixed2 theta = acos(tangentHalfDir.xy);
                fixed2 sqrnorm = sin(pow(2.0f * theta, _SpecularSquare.x));
                
                // fixed theta = min(acos(tangentHalfDir.x), acos(tangentHalfDir.y));
                // fixed2 sqrnorm = sqrt(pow(2.0f * theta, _SpecularSquare.x));
                
                tangentHalfDir = normalize(tangentHalfDir - float3(_SpecularSquare.y * sqrnorm * tangentHalfDir.xy, 0));
                
                
                //卡通高光
                fixed spec = dot(tangentNormal, tangentHalfDir);
                fixed w = fwidth(spec) * 2.0f;
                spec = lerp(0, 1, smoothstep(-w, w, spec - _SpecularScale.z));
                fixed3 specular = _SpecularColor.rgb * spec;
                
                
                return fixed4(diffuse + specular, 1);
            }
            ENDCG
            
        }
    }
}
