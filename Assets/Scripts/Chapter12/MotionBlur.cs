using UnityEngine;
using System.Collections;

public class MotionBlur : PostEffectsBase {

	public Shader motionBlurShader;
	private Material motionBlurMaterial = null;

	public Material material {  
		get {
			motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
			return motionBlurMaterial;
		}  
	}

	[Range(0.0f, 0.9f)]
	public float blurAmount = 0.5f; // 运动模模糊系数，越大，运动轨迹拖尾越明显
	
	private RenderTexture accumulationTexture;

	void OnDisable() {
		DestroyImmediate(accumulationTexture);
	}

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			// Create the accumulation texture
			if (accumulationTexture == null 
                || accumulationTexture.width != src.width 
                || accumulationTexture.height != src.height) {
				DestroyImmediate(accumulationTexture);
				accumulationTexture = new RenderTexture(src.width, src.height, 0);
				accumulationTexture.hideFlags = HideFlags.HideAndDontSave;
				Graphics.Blit(src, accumulationTexture);
			}

			// We are accumulating motion over frames without clear/discard
			// by design, so silence any performance warnings from Unity

            // 表明我们需要进行一个渲染纹理的恢复操作：发生在渲染到纹理而该纹理又没有被提前清空或销毁的情况下
            // 因为，我们需要把上一帧的纹理和当前帧纹理混合，所以，需要进行纹理恢复操作
			accumulationTexture.MarkRestoreExpected();

			material.SetFloat("_BlurAmount", 1.0f - blurAmount);

            // 叠加上一帧渲染结果
			Graphics.Blit (src, accumulationTexture, material);

			Graphics.Blit (accumulationTexture, dest);
		} else
        {
			Graphics.Blit(src, dest);
		}
	}
}
