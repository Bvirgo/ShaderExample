// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
/*
运动模糊：速度映射纹理方案
原理：速度映射纹理，中存储了每个像素的速度，然后使用这个速度来决定模糊的方向和大小

速度映射纹理生成方案：
1、利用审核纹理在片元着色器中为每个像素计算其在世界空间中的位置，这个可以通过使用当前的 视角* 投影矩阵的逆矩阵
对NDC下的顶点坐标进行变化得到
2、当得到世界空间中的顶点坐标之后，我们使用同样的方法获取前一帧的像素对应的世界坐标
3、那么像素的速度，就可以通过这两个坐标的差值获取
*/
Shader "Unity Shaders Book/Chapter 13/Motion Blur With Depth Texture" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}
	SubShader {
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;

		// 深度纹理，由摄像机生成，直接获取
		sampler2D _CameraDepthTexture;

		// 当前摄像机 视角 * 投影矩阵  的逆矩阵
		float4x4 _CurrentViewProjectionInverseMatrix;

		// 上一帧摄像机 视角 * 投影矩阵
		float4x4 _PreviousViewProjectionMatrix;
		half _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
			half2 uv_depth : TEXCOORD1;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			// 平台差异化处理
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
					 
			return o;
		}
		
		// 片元着色器中，通过深度纹理计算世界坐标，效率比较低，还有更好方法在后面
		fixed4 frag(v2f i) : SV_Target {
			// Get the depth buffer value at this pixel.
			// 深度纹理采样，获取深度d
			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);

			// H is the viewport position at this pixel in the range -1 to 1.
			// 像素 在 NDC下的坐标H
			float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);

			// Transform by the view-projection inverse.
			float4 D = mul(_CurrentViewProjectionInverseMatrix, H);

			// Divide by w to get the world position. 
			float4 worldPos = D / D.w;
			
			// Current viewport position 
			float4 currentPos = H;
			// Use the world position, and transform by the previous view-projection matrix.  
			float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
			// Convert to nonhomogeneous points [-1,1] by dividing by w.
			previousPos /= previousPos.w;
			
			// Use this frame's position and last frame's to compute the pixel velocity.
			float2 velocity = (currentPos.xy - previousPos.xy)/2.0f;
			
			float2 uv = i.uv;
			float4 c = tex2D(_MainTex, uv);
			uv += velocity * _BlurSize;

			// 使用速度，对该像素附近像素进行采样,_BlurSize 控制采样距离，相加，取平均值，得模糊效果
			for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
				float4 currentColor = tex2D(_MainTex, uv);
				c += currentColor;
			}
			c /= 3;
			
			return fixed4(c.rgb, 1.0);
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
