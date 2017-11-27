// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 10/Glass Refraction" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {} // 主贴图
		_BumpMap ("Normal Map", 2D) = "bump" {} // 法线贴图
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {} // 天空盒，模拟反射
		_Distortion ("Distortion", Range(0, 100)) = 10
		_RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		GrabPass { "_RefractionTex" }
		
		Pass {		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
			float _Distortion;
			fixed _RefractAmount;
			sampler2D _RefractionTex; // 抓取的屏幕渲染纹理
			float4 _RefractionTex_TexelSize; // 屏幕渲染纹理的中像素大小：比如渲染纹理是：256x512，那么像素大小就是：1/256,1/512
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
			    float4 TtoW1 : TEXCOORD3;  
			    float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert (a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 获取屏幕渲染纹理的采样坐标
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				// TRANSFORM_TEX主要作用是拿顶点的uv去和材质球的tiling和offset作运算，确保材质球里的缩放和偏移设置是正确的
				// 获取主贴图UV
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				// 获取法线贴图UV
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// 法线，是通过法线贴图来采样的
				// 而，法线贴图采样是在切线空间中进行的
				// 最后再采样cubmap，需要在世界空间中进行
				// 所以，这里需要获取：切线空间 到 世界空间 的转换矩阵！
				// TtoW0,1,2 的x y z 分量:分别存储了切线空间到世界空间转换矩阵的每一行！
				// 最后的w分量，用来保存顶点的世界坐标
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target {		
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
				// 切线空间下，法线纹理采样，获取顶点法线信息
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));	
				
				// 偏移屏幕渲染纹理的采样坐标，模拟折射效果
				// Compute the offset in tangent space
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;

				// 透视除法，获取真正的屏幕坐标
				float2 realSrcPos = i.scrPos.xy / i.scrPos.w;

				// 屏幕渲染纹理采样
				fixed3 refrCol = tex2D(_RefractionTex, realSrcPos).rgb;
				
				// Convert the normal to world space
				// 法线向量，从切线空间转换到世界空间
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

				// 通过反射向量，进行天空盒纹理采样，模拟反射
				fixed3 reflDir = reflect(-worldViewDir, bump);
				fixed4 texColor = tex2D(_MainTex, i.uv.xy);

				// 反射向量采样天空盒，模拟反射
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;
				
				// 屏幕纹理采样结果 和 天空盒采样结果 混合
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	
	FallBack "Diffuse"
}
