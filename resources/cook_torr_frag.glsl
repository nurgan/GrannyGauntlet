#version 330 core
uniform sampler2D shadowMapTex;
uniform sampler2D textureMap;

#define M_PI 3.14159

#define MAX_POINT_LIGHTS 10
#define MAX_DIRECTION_LIGHTS 10
#define MAX_AREA_LIGHTS 10

// Structure matches that CPU side in "ShaderManager.h" minus the light type
struct Light {
	vec3 location;
	vec3 color;
	vec3 orientation;
};

uniform vec3 lightPos;
uniform vec3 lightClr;

// TODO(rgarmsen2295): Implement support for point lights
//uniform Light pointLights[MAX_POINT_LIGHTS];
//uniform int numPointLights;

// Currently accepts up to a max of 10 direction lights
uniform Light directionLights[MAX_DIRECTION_LIGHTS];
uniform int numDirectionLights;

// TODO(rgarmsen2295): Implement support for area lights
//uniform Light areaLights[MAX_AREA_LIGHTS];
//uniform int numAreaLights;

uniform vec3 MatAmb;
uniform vec3 MatDif;
uniform vec3 MatSpc;
uniform float MatShiny;

uniform mat4 M;
uniform mat4 V;

uniform int textureActive;

uniform vec2 shadowMapSize;

uniform float PCFkernelRadius = 4.0;

//Poisson Disc for PCF filtering
const vec2 poission[25] = vec2[25](
   vec2(-0.978698, -0.0884121),
   vec2(-0.841121, 0.521165),
   vec2(-0.717460, -0.50322),
   vec2(-0.702933, 0.903134),
   vec2(-0.663198, 0.15482),
   vec2(-0.495102, -0.232887),
   vec2(-0.364238, -0.961791),
   vec2(-0.345866, -0.564379),
   vec2(-0.325663, 0.64037),
   vec2(-0.182714, 0.321329),
   vec2(-0.142613, -0.0227363),
   vec2(-0.0564287, -0.36729),
   vec2(-0.0185858, 0.918882),
   vec2(0.0381787, -0.728996),
   vec2(0.16599, 0.093112),
   vec2(0.253639, 0.719535),
   vec2(0.369549, -0.655019),
   vec2(0.423627, 0.429975),
   vec2(0.530747, -0.364971),
   vec2(0.566027, -0.940489),
   vec2(0.639332, 0.0284127),
   vec2(0.652089, 0.669668),
   vec2(0.773797, 0.345012),
   vec2(0.968871, 0.840449),
   vec2(0.991882, -0.657338)
);

in vec3 positionInCamSpace;
in vec3 normalInWorldSpace;
in vec3 positionInLightSpace;
in vec2 texCoord;

out vec4 color;

// Calculates the fresnel factor - "defines what fraction of incoming light is reflected and what fraction is transmitted"
float calcFresnel(vec3 halfVec, vec3 view) {
	float halfViewDot = max(dot(halfVec, view), 0.0);

	// TODO(rgarmsen2295): Figure out if this should be object dependent
	float normalIncidence = 0.4;

	// Calculate the fresnel factor
	float fresnel = (1.0 - normalIncidence) * pow(1.0 - halfViewDot, 5.0);
	fresnel += normalIncidence;

	return fresnel;
}

// Calculates the roughness/microfacet distribution of the surface using the Beckmanns distribution function
float calcRoughness(vec3 halfVec, vec3 fragNormal) {
	float shiny = MatShiny;
    if (MatShiny == 0.0) {
        shiny = 1.0;
    }

	float matRoughness = 1.0 / shiny;
	float halfNormalDot = max(dot(halfVec, fragNormal), 0.0);
	float halfNormalDotSqrd = pow(halfNormalDot, 2.0);
	float roughnessSqrd = pow(matRoughness, 2.0);

	float roughness = exp((halfNormalDotSqrd - 1.0) / (roughnessSqrd * halfNormalDotSqrd));
	roughness /= M_PI * roughnessSqrd * pow(halfNormalDot, 4.0);

	return roughness;
}

// Calculates the amount of light blocked by microfacets before reaching the surface
float calcGeometricAttenuation(vec3 halfVec, vec3 view, vec3 fragNormal, vec3 lightDir) {
	float halfNormalDot = max(dot(halfVec, fragNormal), 0.0);
	float halfViewDot = max(dot(halfVec, view), 0.0);
	float halfLightDot = max(dot(halfVec, lightDir), 0.0);
	float viewNormalDot = max(dot(view, fragNormal), 0.0);
	float lightNormalDot = max(dot(lightDir, fragNormal), 0.0);

	float amountOfReflectedLightBlocked = 2.0 * halfNormalDot * viewNormalDot / halfViewDot;
	float amountOfLightBlockedBeforeMicrofacet = 2.0 * halfNormalDot * lightNormalDot / halfLightDot;

	float geometricAttenuation = min(1.0, min(amountOfReflectedLightBlocked, amountOfLightBlockedBeforeMicrofacet));

	return geometricAttenuation;
}

// Calculates the total color (specular/diffuse) from directional lights using cook-torrance
// Loops through up to |MAX_DIRECTIONAL_LIGHTS| with a soft cap set by |numDirectionLights|
// Math and explanation of cook-torrance sourced from ruh.li/GraphicsCookTorrance.html
// TODO(rgarmsen2295): Optimize this to remove duplicated calculations (currently reads a bit better though)
vec3 dirLightColor(vec3 fragNormal, vec3 view) {
	vec3 dirLightColor = vec3(0.0);

	// Calculate ambient color
	vec3 ambient = MatAmb;

	for (int i = 0; i < numDirectionLights; ++i) {
		vec3 lightColor = directionLights[i].color;
		vec3 lightDir = normalize(-directionLights[i].orientation);

		// How close are the object normal and the light's direction? (aka Lambertian)
		float lightNormalDot = max(dot(lightDir, fragNormal), 0.0);

		// Calculate diffuse component from light
		float diffuseValue = max(lightNormalDot, 0.0);
		vec3 diffuse = diffuseValue * MatDif * lightColor;

		// How close are the object normal and the view direction?
		float viewNormalDot = max(dot(view, fragNormal), 0.0);

		// Calculate specular component from light
		float specularValue = 0.0;
		if (lightNormalDot != 0.0 && viewNormalDot != 0.0) {
			// Calculate the half-vector between the light vector and the view vector
			vec3 halfVec = normalize(lightDir + view);

			// Calculate the three primary physically-based terms for getting the specular value
			float fresnel = calcFresnel(halfVec, view);
			float roughness = calcRoughness(halfVec, fragNormal);
			float geometricAttenuation = calcGeometricAttenuation(halfVec, view, fragNormal, lightDir);

			specularValue = fresnel * roughness * geometricAttenuation;
			specularValue /= M_PI * lightNormalDot * viewNormalDot;
		}

		// Mix diffuse value with the specular component
		// TODO(rgarmsen2295): Should probably be object dependent
		float diffuseReflection = 0.2;
		specularValue = lightNormalDot * (diffuseReflection + ((1.0 - diffuseReflection) * specularValue));

		// Add light color to total directional color
		dirLightColor += diffuseValue * MatDif * lightColor + specularValue * MatSpc * lightColor;
	}

	dirLightColor += ambient;

    if(textureActive == 1) {
        // lookup texture
        vec3 texColor = texture(textureMap, texCoord).xyz;
        dirLightColor *= texColor;
     }

	return dirLightColor;
}

// Credit for rand function goes to:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
highp float rand(vec2 co)
{
    highp float a = 12.9898;
    highp float b = 78.233;
    highp float c = 43758.5453;
    highp float dt= dot(co.xy ,vec2(a,b));
    highp float sn= mod(dt,3.14);
    return fract(sin(sn) * c);
}

float shadowFactor() {

    // transform to texture spacde
	vec3 shifted = (positionInLightSpace + 1.0) / 2.0;
	// PCF samples and shaded fragment count
	float samples = 9.0;
	float shadedFrags = 0.0;

    for (int i = 0; i < samples; i++) {
        // generate random index for possion disc
        int index = int(25.0*rand(gl_FragCoord.xy))%25;
        // get poisson disc value and scale it
        vec2 offset = vec2(poission[i].x * (PCFkernelRadius / shadowMapSize.x), poission[i].y * (PCFkernelRadius / shadowMapSize.y));
        // apply poisson offset
    	vec3 shiftedOffsetted = vec3(shifted.x + offset.x, shifted.y + offset.y, shifted.z);

        // fragment still in shadow map?
    	if(shiftedOffsetted.x <= 1.0 && shiftedOffsetted.x >= 0.0 && shiftedOffsetted.y <= 1.0 && shiftedOffsetted.y >= 0.0) {
    	    // get current and sampled shadow map depth
            float curDepth = shifted.z;
            float smValue = texture(shadowMapTex, shiftedOffsetted.xy).r;
            // if sampled depth is smaller, fragment is shaded
            if((smValue + 0.001) < curDepth) {
                shadedFrags++;
            }
        }
    }

    // calculate shadow factor
	float PCFfactor = shadedFrags / samples;
	return PCFfactor * 0.5 + (1.0 -PCFfactor) * 1.0;
}

void main() {

	// Normalize the normal of the fragment in world space
	vec3 fragNormalInWorldSpace = normalize(normalInWorldSpace);

	// Gets the view direction by normalizing the negative position of the fragment in camera space
	// So, Camera - worldPosition, except in Camera space -> Camera = (0, 0, 0)
	vec3 view = normalize(-positionInCamSpace);

	// Calculate total specular/diffuse color contributions from all light types
	// TODO(rgarmsen2295): vec3 pointLightColor = pointLightColor();
	vec3 directionalLightColor = dirLightColor(fragNormalInWorldSpace, view);
	// TODO(rgarmsen2295): vec3 areaLightColor = areaLightColor();

	// Shadow Mapping, calculate shadow Factor
    float shadowFactor = shadowFactor();

	// Calculate the total color
	color = shadowFactor * vec4(directionalLightColor, 1.0);
}
