
/* 
原理：
1、噪声纹理 + 透明度测试
2、对噪声纹理采样的结果 和 控制消融程度的阈值比较，
	如果小于阈值，就用clip函数裁剪掉对应像素，这部分就对应“烧毁”区域
3、镂空边缘，的烧焦效果是两种颜色的混合，再用pow函数处理，最后与原纹理混合
*/
Shader "Unity Shaders Book/Chapter 15/Dissolve" {
	Properties {
		_BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0 // 消融程度
		_LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1 // 模拟烧焦效果的线宽
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {} // 法线纹理
		_BurnFirstColor("Burn First Color", Color) = (1, 0, 0, 1) // 烧焦火焰边缘的两种颜色
		_BurnSecondColor("Burn Second Color", Color) = (1, 0, 0, 1)
		_BurnMap("Burn Map", 2D) = "white"{} // 噪声纹理
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass {
			Tags { "LightMode"="ForwardBase" }

			Cull Off
			
			CGPROGRAM
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
		// 引入需要的前向渲染需要的指令
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed _BurnAmount;
			fixed _LineWidth;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			fixed4 _BurnFirstColor;
			fixed4 _BurnSecondColor;
			sampler2D _BurnMap;
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _BurnMap_ST;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uvMainTex : TEXCOORD0;
				float2 uvBumpMap : TEXCOORD1;
				float2 uvBurnMap : TEXCOORD2;
				float3 lightDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
				float3 n:NORMAL;
				SHADOW_COORDS(5)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				// 切线空间
				TANGENT_SPACE_ROTATION;

				// 光照向量，转换到切线空间
  				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
  				
  				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
  				
				// 阴影纹理采样坐标
  				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {

				// 噪声纹理采样
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
				// 阈值裁剪:如果小于0，该像素会被完全剔除,不会往下执行
				clip(burn.r - _BurnAmount);
				
				float3 tangentLightDir = normalize(i.lightDir);

				// 切线空间法线纹理采样
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));
				
				fixed3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				// 切线空间下，计算漫反射
				// 这里不需要通过法线在世界空间中采样，所以没必要把法线转到世界空间
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				/*
				smoothstep(min, max, x):平滑阶梯函数
				值x位于min、max区间中。如果x<=min，返回0；如果x>=max，返回1；如果x在两者之间，按照下列公式返回数据：
				3x *x - 2x * x *x
				*/
				fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);

				// 在烧焦范围（_LineWidth）内混合出烧焦颜色
				fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
				// 效果更逼真pow处理
				burnColor = pow(burnColor, 5);
				
				// 阴影纹理采样
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				//step(a, x)	如果x<a，返回0；否则返回1
				fixed3 finalColor = lerp(ambient + diffuse * atten, 
					burnColor, 
					t * step(0.0001, _BurnAmount));
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
		
		// 像素有，存在性或者位置变化时候，需要单独为消融效果计算对应的阴影
		// Pass to render object as a shadow caster
		Pass {
			Tags { "LightMode" = "ShadowCaster" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			// 引入需要的阴影指令
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"
			
			fixed _BurnAmount;
			sampler2D _BurnMap;
			float4 _BurnMap_ST;
			
			struct v2f {
				V2F_SHADOW_CASTER;
				float2 uvBurnMap : TEXCOORD1;
			};
			
			v2f vert(appdata_base v) {
				v2f o;
				
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
				clip(burn.r - _BurnAmount);
				
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}
