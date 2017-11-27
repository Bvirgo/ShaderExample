
/*
	素描风格：
	1、直接使用6张素描纹理进行渲染
	2、在顶点着色器阶段，逐顶点计算光照，并根据光照结果来决定6张纹理的混合权重，传递给片元着色器
	3、在片元着色器中根据权重来混合6张纹理的采样结果
*/
Shader "Unity Shaders Book/Chapter 14/Hatching" {
	Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		// 纹理平铺系数:越大，素描线条越密集
		_TileFactor ("Tile Factor", Float) = 1
		// 外轮廓
		_Outline ("Outline", Range(0, 1)) = 0.1

		_Hatch0 ("Hatch 0", 2D) = "white" {}
		_Hatch1 ("Hatch 1", 2D) = "white" {}
		_Hatch2 ("Hatch 2", 2D) = "white" {}
		_Hatch3 ("Hatch 3", 2D) = "white" {}
		_Hatch4 ("Hatch 4", 2D) = "white" {}
		_Hatch5 ("Hatch 5", 2D) = "white" {}
	}
	
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		// 外轮廓渲染
		UsePass "Unity Shaders Book/Chapter 14/Toon Shading/OUTLINE"
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag 
			
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			fixed4 _Color;
			float _TileFactor;
			sampler2D _Hatch0;
			sampler2D _Hatch1;
			sampler2D _Hatch2;
			sampler2D _Hatch3;
			sampler2D _Hatch4;
			sampler2D _Hatch5;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 tangent : TANGENT; 
				float3 normal : NORMAL; 
				float2 texcoord : TEXCOORD0; 
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed3 hatchWeights0 : TEXCOORD1;
				fixed3 hatchWeights1 : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				SHADOW_COORDS(4) // 阴影纹理，采样坐标
			};
			
			// 逐顶点光照，根据光照结果，决定6张纹理权重
			v2f vert(a2v v) {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv = v.texcoord.xy * _TileFactor;
				
				fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);

				// 漫反射系数
				fixed diff = max(0, dot(worldLightDir, worldNormal));
				
				// 存储6张纹理的采样权重
				o.hatchWeights0 = fixed3(0, 0, 0);
				o.hatchWeights1 = fixed3(0, 0, 0);
				
				// 为了计算方便，把漫反射系数缩放到[0,7]这个范围
				float hatchFactor = diff * 7.0;
				
				// 顶点根据漫反射系数，只会得到一个权重
				if (hatchFactor > 6.0) {
					// Pure white, do nothing
				} else if (hatchFactor > 5.0) {
					o.hatchWeights0.x = hatchFactor - 5.0;
				} else if (hatchFactor > 4.0) {
					o.hatchWeights0.x = hatchFactor - 4.0;
					o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;
				} else if (hatchFactor > 3.0) {
					o.hatchWeights0.y = hatchFactor - 3.0;
					o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;
				} else if (hatchFactor > 2.0) {
					o.hatchWeights0.z = hatchFactor - 2.0;
					o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;
				} else if (hatchFactor > 1.0) {
					o.hatchWeights1.x = hatchFactor - 1.0;
					o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;
				} else {
					o.hatchWeights1.y = hatchFactor;
					o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;
				}
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// 阴影纹理采样，得到其他物体投射过来的阴影效果
				TRANSFER_SHADOW(o);
				
				return o; 
			}
			
			fixed4 frag(v2f i) : SV_Target {	
				// 6张纹理，带权重采样
				fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
				fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
				fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
				fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
				fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
				fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

				// 素描，外部留白
				fixed4 whiteColor = fixed4(1, 1, 1, 1) 
					* (1 - i.hatchWeights0.x 
					- i.hatchWeights0.y 
					- i.hatchWeights0.z 
					- i.hatchWeights1.x 
					- i.hatchWeights1.y 
					- i.hatchWeights1.z);
				
				//  混合 采样结果 和 白色区域
				fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;
				
				// 阴影值
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
								
				return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
			}
			
			ENDCG
		}
	}
	FallBack "Diffuse"
}
