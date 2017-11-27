/*
水波效果：
1.噪声纹理通常会用作一个高度图，以不断修改水面的法线方向
2.为了模拟水流不断流动的效果，我们会使用时间相关的变量对噪声纹理进行采样
3.得到法线信息后，再进行正常的反射（天空盒采样） + 折射计算（屏幕纹理采样），得到最后的水面波动效果
*/
Shader "Unity Shaders Book/Chapter 15/Water Wave" {
	Properties {
		_Color ("Main Color", Color) = (0, 0.15, 0.115, 1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		// 噪声纹理，采样作为法线信息
		// 纹理设置：纹理类型设置为Normal Map ;勾选：Create from grayscale来完成
		_WaveMap ("Wave Map", 2D) = "bump" {} 
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
		_WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
		_WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
		_Distortion ("Distortion", Range(0, 100)) = 10
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		/*
		1。Queue 设置为 Transparent：可以确保该物体渲染时候，其他所有不透明物体都已经被渲染完成，否则就可能
			无法正确得到“透过水面看到的图像”
		2、RenderType 设置为 Opaque：是为了使用着色器替换技术（Shader Repalcement）时，该物体可以在我们需要
			得到摄像机的深度和法线纹理时候，能被正确的渲染到深度和法线纹理中.
		*/
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		GrabPass { "_RefractionTex" }
		
		Pass {
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WaveMap;
			float4 _WaveMap_ST;
			samplerCUBE _Cubemap;
			fixed _WaveXSpeed;
			fixed _WaveYSpeed;
			float _Distortion;	
			sampler2D _RefractionTex;
			float4 _RefractionTex_TexelSize;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
				float4 TtoW1 : TEXCOORD3;  
				float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 屏幕纹理采样坐标
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// 切线空间 转 世界空间 3x3矩阵,W存储世界坐标信息
				// 切线空间下的3个坐标轴（X,Y,Z） 分别对应了：切线，副切线，法线方向在世界空间下的表示
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

				// x,y方向波动速度
				float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
				
				// 切线空间，法线纹理采样，获取法线信息
				// 这里采样两次，是为了模拟两层交叉的水面波动效果
				// Get the normal in tangent space
				fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
				fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
				fixed3 bump = normalize(bump1 + bump2);
				
				// 扭曲，偏移 屏幕纹理采样坐标， 模拟折射
				// Compute the offset in tangent space
				/*
				1、_Distortion：扭曲度，值越大，水面背后的物体看起来变形程度越大
				2、这里使用了切线空间下的法线来进行偏移，是因为切线空间下的法线可以反映顶点局部空间下的法线法相
				3、需要注意，在计算偏移后的屏幕坐标时，我们把 偏移量 * 屏幕坐标的Z分量，
					这是为了模拟深度越大，折射程度越大的效果；
				4、透视除法，获取屏幕坐标,采样屏幕纹理
				*/
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
				float2 _scrPos = i.scrPos.xy / i.scrPos.w;
				fixed3 refrCol = tex2D( _RefractionTex, _scrPos).rgb;
				
				// 法线，从切线空间变换到世界空间，计算反射向量，采样天空盒，模拟反射
				// Convert the normal to world space
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed);
				fixed3 reflDir = reflect(-viewDir, bump);
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;
				
				// 加入 菲涅尔系数，模拟菲涅尔现象:V  和  N 决定
				// saturate(x) = Max(0,x) = clamp(0,1,x)
				fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
				//fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);
				fixed3 finalColor = lerp(refrCol, reflCol, fresnel);
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	// Do not cast shadow
	FallBack Off
}
