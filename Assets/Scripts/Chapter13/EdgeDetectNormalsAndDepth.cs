using UnityEngine;
using System.Collections;

public class EdgeDetectNormalsAndDepth : PostEffectsBase {

	public Shader edgeDetectShader;
	private Material edgeDetectMaterial = null;
	public Material material {  
		get {
			edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
			return edgeDetectMaterial;
		}  
	}

	[Range(0.0f, 1.0f)]
	public float edgesOnly = 0.0f;

	public Color edgeColor = Color.black;

	public Color backgroundColor = Color.white;

	public float sampleDistance = 1.0f; 

	public float sensitivityDepth = 1.0f;

	public float sensitivityNormals = 1.0f;
	
	void OnEnable() {
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
	}

    /*
     * 1.默认情况下，OnRenderImage 是在渲染完所有不透明，透明物体之后被调用，也就是对所有的场景对象都会产生影响
     * 2.但是，有些时候我们想在不透明物体渲染完之后，在透明物体渲染之前执行，而对透明物体不产生影响
     */
    [ImageEffectOpaque]
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_EdgeOnly", edgesOnly);
			material.SetColor("_EdgeColor", edgeColor);
			material.SetColor("_BackgroundColor", backgroundColor);
			material.SetFloat("_SampleDistance", sampleDistance); // 采样距离
            // 对深度、法线进行边缘检测的灵敏度:深度，法线相差多少，算一条边？
			material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));

			Graphics.Blit(src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
