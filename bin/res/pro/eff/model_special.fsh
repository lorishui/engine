precision mediump float;
precision mediump int;

uniform sampler2D tex_Diffuse;
uniform sampler2D tex_DiffuseAlpha;
uniform sampler2D tex_Bump;
uniform sampler2D tex_SpecularMap;
uniform samplerCube tex_ReflectionMap;
uniform sampler2D tex_LightMap;
uniform sampler2D tex_EmissiveMap;
uniform sampler2D tex_FilterMap;
#ifdef USE_PCF
uniform highp sampler2DShadow tex_Shadow;
#else
uniform sampler2D tex_Shadow;
#endif
uniform sampler2D tex_WarFog;
uniform sampler2D tex_LightMap1;
uniform sampler2D tex_LightMap2;
uniform sampler2D tex_AmbientOcclusion;

varying mediump vec4 oTex0;

#ifdef VERTEX_NORMAL
varying mediump vec3 oNormal;

#if defined LIGHTMAP
varying mediump vec4 oTex1;
#endif
#endif

#ifdef FILTERMAP
varying mediump vec2 oTexFilter;
#endif

#if defined NORMALMAP
varying mediump vec3 oTangent;
varying mediump vec3 oBinormal;
#endif

varying mediump vec4 oDiffuse;
varying mediump vec4 oViewToVertex;

varying mediump vec2 oClipDistance;

#ifdef SHADOWMAP
varying mediump vec4 oTexCoordShadow;
uniform mediump float c_ShadowParam;
#endif

#if defined FOGEXP || defined FOGLINEAR || defined HEIGHT_FOG
varying mediump vec4 oFog;
#endif

#ifdef CAMERALIGHT
varying mediump	float oCameraLightInten;
uniform mediump vec4 c_CameraLightDiffuse;
#endif

// PS Constants
uniform mediump vec4 c_FallOffParam;
uniform mediump vec4 c_MaterialAmbient;
uniform mediump vec4 c_MaterialAmbientEx;
uniform mediump vec4 c_SubSurfaceParam;

uniform mediump float c_fBumpScale;

//scene
uniform mediump vec3 c_vLightDir;
uniform mediump vec4 c_LightAmbient;
uniform mediump vec4 c_LightDiffuse;

//???
uniform mediump vec4 c_PointLightPosition;
uniform mediump vec4 c_PointLightDiffuse;

uniform mediump mat4 c_mtxViewInverse;
uniform mediump vec4 c_MaterialDiffuse;
uniform mediump vec4 c_MaterialEmissive;
uniform mediump vec4 c_MaterialSpecular;
uniform mediump vec4 c_AppendColor;

uniform mediump float c_fSpecularPower;
uniform mediump float c_fAlphaRefValue;

uniform mediump vec3 c_vLightMapColorScale;

uniform mediump vec4 c_FilterParam;

uniform mediump vec4 c_HDRScaleInfo[6];

#if defined WARFOG
	varying mediump vec2 oTexWarFog;
	uniform mediump vec4 c_vWarFogRange;
#endif

#if defined WATER
	#if defined FOAM
		uniform sampler2D tex_Foam;
	#endif
varying mediump vec4 oTex1;  //if rendering water�� xy = bumpUv1; zw= v_foamUv
varying mediump vec4 oDarkColor;// xyz = dark color, w = reflection power
varying mediump vec4 oLightColor;
varying mediump vec4 oLightMap;
#endif

mediump vec4 lerp(mediump vec4 u, mediump vec4 v, mediump float t)
{
	return u + (v-u)*t;
}

mediump vec3 lerp(mediump vec3 u, mediump vec3 v, mediump float t)
{
	return u + (v-u)*t;
}

mediump vec3 normal_calc(mediump vec3 map_normal, mediump float bump_scale)
{
	mediump vec3 v = vec3(0.5, 0.5, 1.0);
	map_normal = lerp(v, map_normal, bump_scale);
	map_normal = (map_normal * 2.0) - 1.0;
	return map_normal;
}

// �������ͼ����
mediump vec3 RNM_calc(vec3 normalmap, 
	vec3 lightmap1, vec3 lightmap2, vec3 lightmap3, 
	vec3 lightMapMin, vec3 lightMapRange, 
	vec3 lightMapMin1,vec3 lightMapRange1, 
	vec3 lightMapMin2,vec3 lightMapRange2)
{
	const mediump vec3 bumpBasis = vec3(0.8165, 0.0, 0.577);
	const mediump vec3 bumpBasis1 = vec3(-0.408, -0.707, 0.577);
	const mediump vec3 bumpBasis2 = vec3(-0.408, 0.707, 0.577);

	mediump vec3 dp;

	dp.x = dot(normalmap, bumpBasis);
	dp.y = dot(normalmap, bumpBasis1);
	dp.z = dot(normalmap, bumpBasis2);
	dp = clamp(dp, 0.0, 1.0);

	return dp.x * (lightmap1 * lightMapRange + lightMapMin) 
		+ dp.y * (lightmap2 * lightMapRange1 + lightMapMin1) 
		+ dp.z * (lightmap3 * lightMapRange2 + lightMapMin2);
}

#ifdef SHADOWMAP
	#ifdef USE_PCF
	float shadow_lookup( float x, float y )                              
	{                                                              
	   mediump float pixelSize = 0.0009765625;                          
	   mediump vec4 offset = vec4 ( x * pixelSize * oTexCoordShadow.w,       
	                        y * pixelSize * 2.0 * oTexCoordShadow.w,
	                        0.0, 0.0);                            
	   mediump vec4 tex_uv = oTexCoordShadow * 0.5 + 0.5;
	   return shadow2DProjEXT(tex_Shadow, tex_uv + offset);
	}  
	#endif

mediump vec4 final_shadow_color(in mediump float shadow)
{
	mediump float v  = 1.0 - clamp((1.0 - shadow) * c_ShadowParam, 0.0, 1.0);

	mediump vec4 fShadow = vec4(v, v, v, v);
	return fShadow;
}
#endif

void main (void)
{
	mediump vec3 nor;
	mediump float bias = 0.0;
#ifdef REFRACTION
	#ifdef VERTEX_NORMAL
		#ifdef NORMALMAP
			nor = normal_calc(texture2D(tex_Bump, oTex0.xy).xyz, c_fBumpScale);	
			nor = nor.x * oTangent + nor.y * oBinormal + nor.z * oNormal;
			nor = normalize(nor);
		#else
			nor = normalize(oNormal);
		#endif
	#else
		nor = vec3(0.0, 0.0, 0.0);
	#endif

	vec4 crRefraction = vec4(0.5, 0.5, 0.5, 0.5);
	vec4 specColor = vec4(0.3, 0.2, 0.1, 1.0);

	#ifdef  DIFFUSEMAP
		crRefraction = texture2D(tex_Diffuse, oTex0.xy);
	#endif

	crRefraction.xyz -= 0.5;

	#ifdef VERTEX_COLOR
		crRefraction *= oDiffuse;
	#endif

	#ifdef OPACITY
		crRefraction.w *= c_AppendColor.w;
	#endif

	vec4 finalColor;

	#ifdef NORMALMAP
		finalColor.xy = crRefraction.xy * c_MaterialAmbient.xy;

		finalColor.xy += crRefraction.x * oTangent.xy
			+ finalColor.y * oBinormal.xy
			+ finalColor.z * oNormal.xy;
	#else
		finalColor.xyz = crRefraction.xyz * c_MaterialAmbient.xyz;
		finalColor.xy += finalColor.z * nor.xy;
	#endif

		finalColor.xyz += 0.5;
		finalColor.w = crRefraction.w / exp(oClipDistance.y * 0.05);

		gl_FragColor = finalColor;

#elif defined WATER_SIMPLE

#elif defined WATER
	vec4 normalMapValue = vec4(0.0, 0.0, 0.0, 0.0);

	#ifdef  DIFFUSEMAP
		normalMapValue = texture2D(tex_Diffuse, oTex1.xy);
	#endif

	mediump vec4 diffuse_color = vec4(mix(oLightColor.xyz, oDarkColor.xyz, (normalMapValue.x * oTex0.y) + (normalMapValue.y * (1.0 - oTex0.y))), oTex0.x);

	#if defined REFLECTION
		float reflectFractor = exp2(log2(((normalMapValue.z * oTex0.y) + (normalMapValue.w * (1.0 - oTex0.y))) * oTex0.z) * oTex0.w + oDarkColor.w);
		diffuse_color.xyz = diffuse_color.xyz + reflectFractor * c_LightDiffuse.xyz;
	#endif

	#ifdef USE_FOAM
		#if defined LIGHTMAP
			vec3 foamColor = texture2D(tex_LightMap, v_worldPos).xyw * vec3(texture2D(tex_Foam, oTex1.zw).x * 1.5, 1.3, 1.0);
		#else
			vec3 foamColor = vec3(texture2D(tex_Foam, oTex1.zw).x * 1.5, 1.3, 1.0);
		#endif

			diffuse_color = mix(diffuse_color, vec4(0.92, 0.92, 0.92, foamColor.x), min(0.92, foamColor.x)) * foamColor.yyyz;
	#endif

		gl_FragColor = diffuse_color;
#else
	#ifdef CLIPPLANE
		if(oClipDistance.x < 0.0)
		{
			discard;
		}
	#endif

	mediump vec4 diffuse_color = vec4(1,1,1,1);
	mediump vec3 specular_color = vec3(0, 0, 0);
	
	#ifdef SHADOWMAP
		mediump vec2 tex_uv = (vec2(0.5, 0.5) * (oTexCoordShadow.xy / oTexCoordShadow.w)) + vec2(0.5, 0.5);
		mediump vec4 shadow_Inten = texture2D(tex_Shadow, tex_uv, bias);

		#ifdef USE_PCF
			float sum = shadow_lookup(-2.0, -2.0);
			sum += shadow_lookup(-2.0, 0.0);
			sum += shadow_lookup(-2.0, 2.0);
			sum += shadow_lookup(0.0, -2.0);
			sum += shadow_lookup(0.0, 0.0);
			sum += shadow_lookup(0.0, 2.0);
			sum += shadow_lookup(2.0, -2.0);
			sum += shadow_lookup(0.0, 0.0);
			sum += shadow_lookup(2.0, 2.0);                             
			                                                                                            
			sum = sum * 0.1111; //divided by 9                                        
			mediump vec4 shadow_Inten = vec4(sum);
			shadow_Inten = final_shadow_color(shadow_Inten.x);
		#else
			shadow_Inten = final_shadow_color(shadow_Inten.x);
		#endif
	#endif  
	
	mediump vec3 light_dir = c_vLightDir;
	
	#ifdef DYNAMICLIGHTING
			
		#ifdef VERTEX_NORMAL
			#ifdef NORMALMAP
				nor = normal_calc(texture2D(tex_Bump, oTex0.xy, bias).xyz, c_fBumpScale);	
				nor = nor.x * oTangent + nor.y * oBinormal + nor.z * oNormal;
				nor = normalize(nor);
			#else
				nor = normalize(oNormal);
			#endif
		#else
			nor = vec3(0.0, 0.0, 0.0);		
		#endif

		mediump vec3 ambient_light = c_LightAmbient.xyz;
		#ifdef SPHEREAMBIENT
		 	// hemispherical lighting: normals facing upside are slightly brighter shaded in ambient
			#ifdef SKELETON
				ambient_light *= 1.0 + dot(nor, c_mtxViewInverse[1].xyz) * 0.25;
			#else
				ambient_light *= 0.75 + dot(nor, c_mtxViewInverse[1].xyz) * 0.25;
			#endif
		#endif
		
		#ifndef VERTEX_NORMAL
			diffuse_color.xyz = vec3(0.0, 0.0, 0.0);
		#else
			#ifdef SHADOWMAP
				diffuse_color.xyz = max(dot(light_dir, nor), 0.0) * c_LightDiffuse.xyz * shadow_Inten.x;
			#else 
				diffuse_color.xyz = max(dot(light_dir, nor), 0.0) * c_LightDiffuse.xyz;
			#endif
		#endif

		#ifdef  CAMERALIGHT
			diffuse_color.xyz += c_CameraLightDiffuse.xyz * oCameraLightInten;
		#endif
		
		diffuse_color.xyz *= c_MaterialDiffuse.xyz;
		
		#ifdef SHADOWMAP
			diffuse_color.xyz += c_MaterialAmbient.xyz * ambient_light * shadow_Inten.x;
		#else 
			diffuse_color.xyz += c_MaterialAmbient.xyz * ambient_light;
		#endif
		
		#ifdef POINTLIGHT
			mediump vec3 to_point_vector = c_PointLightPosition.xyz - oViewToVertex.xyz;
			mediump float to_point_distance = length(to_point_vector);
			mediump float LdotN = dot(to_point_vector / to_point_distance, nor);
			mediump float point_light_inten = max(LdotN, 0.0);
			mediump float point_light_rang = max(0.0, 1.0 - to_point_distance / c_PointLightPosition.w);
			
			diffuse_color.xyz += point_light_inten * point_light_rang
				* c_MaterialDiffuse.xyz * c_PointLightDiffuse.xyz;
		#endif
	
		#ifdef DIFFUSE
			diffuse_color.xyz *= oDiffuse.xyz * 2.0;
			diffuse_color.w *= oDiffuse.w;
		#endif
	#else
		#ifdef LIGHTMAP	
			mediump vec3 lightmap_color = texture2D(tex_LightMap, oTex0.zw, bias).xyz;

			#ifdef VERTEX_NORMAL
				#ifdef NORMALMAP
					nor = normal_calc(texture2D(tex_Bump, oTex0.xy, bias).xyz, c_fBumpScale);
				
					#ifdef SPHEREAMBIENT // RNM
						mediump vec3 lightmap_color1 = texture2D(tex_LightMap1, oTex1.xy, bias).xyz;
						mediump vec3 lightmap_color2 = texture2D(tex_LightMap2, oTex1.zw, bias).xyz;

						lightmap_color.xyz = RNM_calc(nor, 
							lightmap_color.xyz, lightmap_color1.xyz, lightmap_color2.xyz, 
							c_HDRScaleInfo[0].xyz,c_HDRScaleInfo[1].xyz,  
							c_HDRScaleInfo[2].xyz,c_HDRScaleInfo[3].xyz,  
							c_HDRScaleInfo[4].xyz,c_HDRScaleInfo[5].xyz);

						mediump vec3 ao_color = texture2D(tex_AmbientOcclusion, oTex1.xy, bias).xyz;
						lightmap_color.xyz += ao_color * c_MaterialAmbient.xyz * c_LightAmbient.xyz;
					#else
						lightmap_color.xyz = lightmap_color.xyz * c_vLightMapColorScale.xyz;
					#endif
					
					nor = nor.x * oTangent + nor.y * oBinormal + nor.z * oNormal;
					nor = normalize(nor);
				#else
					nor = oNormal;
					lightmap_color.xyz = lightmap_color.xyz * c_vLightMapColorScale.xyz;
				#endif
			#else
				lightmap_color.xyz = lightmap_color.xyz * c_vLightMapColorScale.xyz;
			#endif

			diffuse_color.xyz = diffuse_color.xyz * lightmap_color.xyz;
			
		#endif
		
		#ifdef DIFFUSE
			diffuse_color.xyz *= oDiffuse.xyz * 2.0;
		#endif

		#ifdef SHADOWMAP
			diffuse_color.xyz *= shadow_Inten.x;
		#endif
	
	#endif
			
	#ifdef DIFFUSEMAP
		mediump vec4 crTexDiffuse = texture2D(tex_Diffuse, oTex0.xy, bias);
		
		#ifdef DIFFUSEMAP_ALPHA
			crTexDiffuse.a = texture2D(tex_DiffuseAlpha, oTex0.xy).r;
		#endif
			
		#ifdef SATURATION
			mediump float lum = dot(crTexDiffuse.xyz, vec3(0.299, 0.587, 0.114));
			crTexDiffuse.xyz = max((crTexDiffuse.xyz - lum) * c_MaterialEmissive.w + lum, 0.0);
		#endif
	
		#ifdef FILTERMAP
			mediump vec4 crBaseColor = vec4(c_FilterParam.yyy, c_FilterParam.w);
			mediump vec4 crTexFilter = texture2D(tex_FilterMap, oTexFilter, bias) * vec4(c_FilterParam.xxx, c_FilterParam.z);
			crTexFilter += crBaseColor;
			crTexDiffuse *= crTexFilter;
		#endif
	
		diffuse_color *= crTexDiffuse;
	#endif
	
	#ifdef APPENDCOLOR
		diffuse_color *= c_AppendColor;
	#endif
	
		
	#ifdef DISAPPEAR
		diffuse_color.w *= 1.0 - clamp((oViewToVertex.w - 25.0) / 50.0, 0.0, 1.0);
	#endif
	
	
	//#ifdef CLIPBLEND
	//	if(diffuse_color.w - 0.9 <0.0)
	//	{
	//		discard;
	//	}
	//	//clip(diffuse_color.w - 0.9);
	//#else
	//	#ifdef CLIPSOLID
	//		if(0.9 - diffuse_color.w <0.0)
	//		{
	//			discard;
	//		}
	//		//clip(0.9 - diffuse_color.w);
	//	#else
	//		#ifdef ALPHATEST
	//			#ifndef ONLYCOLORPASS
	//				#ifdef ALPHATEST_GREATERQUAL
	//					if(diffuse_color.w - c_fAlphaRefValue >= 0.0)
	//					{
	//						discard;
	//					}
	//				#else
	//					if(diffuse_color.w - c_fAlphaRefValue <0.0)
	//					{
	//						discard;
	//					}
	//				#endif
	//			#endif
	//		#endif
	//	#endif
	//#endif
	
	#ifdef SPECULARMAP
		mediump vec4 specular_tex = texture2D(tex_SpecularMap, oTex0.xy, bias);
		mediump vec3 specular_material = c_MaterialSpecular.xyz * specular_tex.xyz;
		mediump float gloss = max(c_fSpecularPower, 0.000001) * specular_tex.w;
	#endif
	
	#if defined SPECULAR && !defined SPECULARMAP
		mediump vec3 specular_material = c_MaterialSpecular.xyz;
		mediump float gloss = max(c_fSpecularPower, 0.000001);
	#endif
	
	#if defined REFLECTION	
		mediump vec3 reflect_inten = vec3(c_MaterialDiffuse.w, c_MaterialDiffuse.w, c_MaterialDiffuse.w);
		#if defined SPECULARMAP
			reflect_inten *= specular_material.xyz;
		#endif
	#endif
	
	#if defined SPECULAR || defined SPECULARMAP
		mediump float specular_inten = pow(max(dot(reflect(normalize(oViewToVertex.xyz), nor), light_dir), 0.000001), gloss);
		#ifdef SHADOWMAP
			specular_inten *= shadow_Inten.x;
		#endif
	#endif
	
	#if defined SPECULAR || defined SPECULARMAP
		specular_color = specular_inten * specular_material.xyz * c_LightDiffuse.xyz;
	#endif 
	
	#if defined EMISSIVEMAP
		#ifdef SKINEFFECT
			mediump vec4 crTexSubSurface = texture2D(tex_EmissiveMap, oTex0.xy, bias);
			crTexSubSurface.xyz *= c_LightDiffuse.xyz;
			mediump float sss_inten = (dot(light_dir, nor) + c_SubSurfaceParam.x) / (1.0 + c_SubSurfaceParam.x);
			#ifdef SHADOWMAP
				diffuse_color.xyz += max(sss_inten, 0.0) * c_SubSurfaceParam.y * crTexSubSurface.xyz * shadow_Inten.x;
			#else
				diffuse_color.xyz += max(sss_inten, 0.0) * c_SubSurfaceParam.y * crTexSubSurface.xyz;
			#endif
		#else
			#ifdef EMISSIVE
				mediump vec3 crTexEmissive = c_MaterialEmissive.xyz * texture2D(tex_EmissiveMap, oTex0.xy, bias).xyz;
				diffuse_color.xyz += crTexEmissive.xyz;
			#endif
		#endif
	#else
		#ifdef SKINEFFECT
			mediump float sss_inten = (dot(light_dir, nor) + c_SubSurfaceParam.x) / (1.0 + c_SubSurfaceParam.x);
			#ifdef SHADOWMAP
				diffuse_color.xyz += max(sss_inten, 0.0F) * c_SubSurfaceParam.y
					* c_LightDiffuse.xyz * max(shadow_Inten.x, 0.7);
			#else
				diffuse_color.xyz += max(sss_inten, 0.0) * c_SubSurfaceParam.y
					* c_LightDiffuse.xyz;
			#endif
		#else
			#ifdef EMISSIVE
				diffuse_color.xyz += c_MaterialEmissive.xyz;
			#endif
		#endif
	#endif
	
	#if defined REFLECTION
		mediump float reflect_factor = c_MaterialDiffuse.w;
		mediump vec3 vReflect = reflect(normalize(oViewToVertex.xyz), nor);
		mediump vec4 crTexReflect = textureCube (tex_ReflectionMap, vReflect);
		specular_color += crTexReflect.xyz * reflect_inten.xyz * reflect_factor;
	#endif
	
	#if defined DIFFUSEMAP && defined SPECULAR && !defined SPECULARMAP
		specular_color.xyz *= crTexDiffuse.w;
	#endif
	
	#if defined SPECULAR || defined SPECULARMAP || defined REFLECTION
		diffuse_color.xyz += specular_color.xyz;
	#endif
	
	#if defined FALLOFF
		mediump float falloff_inten = -dot(normalize(oViewToVertex.xyz), nor);		
		falloff_inten = 1.0 - max(falloff_inten, 0.0);
		falloff_inten = pow(max(falloff_inten, 0.000001), c_FallOffParam.w);
	
		#ifdef DIFFUSEMAP
			diffuse_color.xyz += crTexDiffuse.xyz * falloff_inten * c_FallOffParam.xyz;
		#else
			diffuse_color.xyz += falloff_inten * c_FallOffParam.xyz;
		#endif
	#endif
	
	#ifdef BLEND_ENHANCE
		#if defined FOGEXP || defined FOGLINEAR || defined HEIGHT_FOG
			diffuse_color.xyz = diffuse_color.xyz * oFog.w;
		#endif
	#else
		#if defined FOGEXP || defined FOGLINEAR || defined HEIGHT_FOG
			diffuse_color.xyz = diffuse_color.xyz * oFog.w + oFog.xyz;
		#endif
	#endif
	
		diffuse_color.xyz = diffuse_color.xyz + c_MaterialAmbientEx.xyz;
		
	#ifdef WARFOG
		mediump vec2 vTexCoord = oTexWarFog.xy;
		mediump vec4 crWarFog = texture2D(tex_WarFog, vTexCoord, bias);

		diffuse_color.xyz = diffuse_color.xyz * mix(c_vWarFogRange.x, c_vWarFogRange.y, crWarFog.w);
	#endif
	
	#ifdef BWCOLOR
		mediump float bwdiffuse = (diffuse_color.x + diffuse_color.y + diffuse_color.z) * 0.3;
		diffuse_color.xyz = vec3(bwdiffuse,bwdiffuse,bwdiffuse);
	#endif

		gl_FragColor = diffuse_color;
#endif

}
