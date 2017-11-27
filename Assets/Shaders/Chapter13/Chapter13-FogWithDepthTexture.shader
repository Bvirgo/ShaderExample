// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 13/Fog With Depth Texture" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		float4x4 _FrustumCornersRay;
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture;
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
			half2 uv_depth : TEXCOORD1;
			float4 interpolatedRay : TEXCOORD2;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			/*
			平台差异化处理：主要是屏幕特效shader
			1、DX 和OpenGL 两个平台屏幕的原点不一致，OpenGL在左下角，DX在左上角
			2、默认情况下，U3D会根据平台的不同，自动帮我们翻转屏幕渲染到纹理之后的纹理，
			避免纹理采样时候，不同平台出现倒置；
			3、但是，如果开启了抗锯齿，在DX平台当屏幕渲染到纹理时候，U3D就不会自动帮我们翻转该纹理
			这就会出现DX平台，采样屏幕渲染纹理，倒置
			4、所以，我们需要在顶点着色器中翻转某些渲染纹理（比如，深度纹理，由其他脚本传递过来的纹理）
			5、UNITY_UV_STARTS_AT_TOP：判断当前平台是不是DX
			6、如果是DX，开启抗锯齿之后，_MainTex_TexelSize.y < 0 ,这个时候，我们翻转一下
			*/
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
			// 屏幕渲染纹理，均分四块
			int index = 0;
			// 左下角
			if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) 
			{
				index = 0;
			}
			// 右下角
			else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) 
			{
				index = 1;
			}
			// 右上角
			else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) 
			{
				index = 2;
			}
			// 左上角
			else 
			{
				index = 3;
			}

			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			/*
			根据区域，选择插值的射线方向
			Eg：左上角区域，就选择左上角顶点的射线方向（也就是该顶点相对于摄像机的偏移量），
			顶点着色器，把数据传递给片元着色器，光栅化会进行插值处理！
			也就是说，在片元着色器中，对每个像素取得的interpolatedRay，是已经对左上角射线插值过后的值了
			可以直接用：相机世界坐标 + 像素偏移 = 像素世界坐标
			*/

			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target 
		{
			// 深度纹理采样，摄像机世界坐标 + 像素点相对于摄像机的偏移量 = 像素点的世界坐标
			// 摄像机空间下的线性深度值
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
			
			// 求距离：超过雾效范围，截取出来是0，雾效范围以内，按比例算浓度，混合雾效颜色  
			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			fogDensity = saturate(fogDensity * _FogDensity);
			
			fixed4 finalColor = tex2D(_MainTex, i.uv);
			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
			
			return finalColor;
		}
		
		ENDCG
		
		Pass {
			ZTest Always Cull Off ZWrite Off
			     	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
	} 
	FallBack Off
}
