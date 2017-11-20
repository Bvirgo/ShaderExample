// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
/*运动模糊
	1.原理：保存之前的渲染结果，不断把当前的渲染图像叠加到之前的渲染图像中，从而产生一种运动轨迹的视觉效果
*/
Shader "Unity Shaders Book/Chapter 12/Motion Blur" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurAmount ("Blur Amount", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		fixed _BlurAmount;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
					 
			return o;
		}
		// 
		/*
		1、纹理采样,讲采样结果的A通道设置为_BlurAmount，以便在后面混合时候可以使用它的透明通道进行混合
		*/
		fixed4 fragRGB (v2f i) : SV_Target {
			return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
		}
		
			// 更新A通道
		half4 fragA (v2f i) : SV_Target {
			return tex2D(_MainTex, i.uv);
		}
		
		ENDCG
		
		ZTest Always 
		Cull Off 
		ZWrite Off
		
		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			//ColorMask可以让我们制定渲染结果的输出通道，而不是通常情况下的RGBA这4个通道全部写入。
			//可选参数是 RGBA 的任意组合以及 0， 这将意味着不会写入到任何通道
			// 这个pass的意思：就是把渲染结果的RGB 3个通道写入颜色缓存中，A通道抛弃
			ColorMask RGB
			/*
			之所以，要使用两个pass，一个用于更新渲染纹理的RGB通道，一个用于更新A通道，
			是因为在更新RGB时候，我们需要设置它的A通道用来混合图像纹理，
			但是又不希望我们设置的A通道值写入渲染纹理中。

			我擦，就是这个通道执行完之后，会有一个Blend操作，
			就可以根据我们设置的A通道值来混合颜色缓存中的结果，也就是实现运动模糊效果！
			而，通道2，仅仅就是更新颜色缓存中的A通道而已！
			*/
			CGPROGRAM
			
			#pragma vertex vert  
			#pragma fragment fragRGB  
			
			ENDCG
		}
		
		Pass 
		{   
			// 这个Pass渲染结果 和 颜色缓冲混合时候，只保留这个pass结果
			Blend One Zero
			// 这个Pass的意思：就是把渲染结果的A 通道写入颜色缓存中
			ColorMask A
			   	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment fragA
			  
			ENDCG
		}
	}
 	FallBack Off // 关闭
}
