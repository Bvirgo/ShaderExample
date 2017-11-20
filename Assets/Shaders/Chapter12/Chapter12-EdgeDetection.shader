// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
/*
卷积操作：
1、使用一个3x3大小的卷积核，对一个5x5区域的纹素进行卷积操作
2、当计算坐标A处的卷积结果时，先把卷积核中心放置于A处
3、翻转卷积核之后再依次计算卷积核中每个元素（权重）和其覆盖纹素值的乘积，累加求和，得到新的像素值
4.应用场景：边缘检测，高斯模糊

边缘检测：
	1、利用卷积操作原理，选择特定的卷积核，计算当前纹素和周围纹素的梯度值
	2、梯度值越大，说明当前纹素是在边缘位置
*/
Shader "Unity Shaders Book/Chapter 12/Edge Detection" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
	}

		// 基于屏幕颜色信息的边缘检测算法：
		// 由于实际场景中，物体的纹理，阴影等信息都会影响边缘检测结果，
		// 所以仅仅基于颜色检测，不准确实际利用价值不高！
	SubShader {
		Pass {  
			ZTest Always 
			Cull Off 
			ZWrite Off
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			
			#pragma vertex vert  
			#pragma fragment fragSobel
			
			sampler2D _MainTex;  
			uniform half4 _MainTex_TexelSize; // 纹理中纹素大小；Eg：512 x 512 ,纹素：1/512
			fixed _EdgeOnly; // 0:边缘颜色 叠加在原渲染图像上； 1：只显示边缘，不显示原渲染图像
			fixed4 _EdgeColor;
			fixed4 _BackgroundColor;
			
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv[9] : TEXCOORD0;
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				half2 uv = v.texcoord;
				
				// 9个，相邻的纹理坐标,用于卷积采样
				o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
				o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
				o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
				o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
				o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
				o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
				o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
				o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
				o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);
						 
				return o;
			}
			
			// 计算颜色的亮度值
			fixed luminance(fixed4 color) {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
			}
			
			// 计算当前像素在x，y 方向的梯度值
			half Sobel(v2f i) 
			{
				// x 上的卷积核
				const half Gx[9] = {-1, -2, -1,
									0,  0,  0,
									1,  2,  1};
				// y 上的卷积核
				const half Gy[9] = {-1,  0,  1,
									-2,  0,  2,
									-1,  0,  1};		
				
				half texColor;
				half edgeX = 0;
				half edgeY = 0;

				// 附近纹素亮度值，卷积核累加
				for (int it = 0; it < 9; it++) 
				{
					texColor = luminance(tex2D(_MainTex, i.uv[it]));
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}
				
				half edge = 1 - abs(edgeX) - abs(edgeY);
				
				return edge;
			}
			
			fixed4 fragSobel(v2f i) : SV_Target {
				half edge = Sobel(i);
				
				// i.uv[4]:这个就是当前顶点的uv坐标
				// edge:值越小，边缘越明显
				// 在原渲染图像的基础上，叠加边缘颜色
				fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);

				// 在背景色的基础上，显示边缘颜色
				fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
 			}
			
			ENDCG
		} 
	}
	FallBack Off
}
