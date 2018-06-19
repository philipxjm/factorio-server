#version 120

uniform sampler2D gameview; // "diffuse" texture
uniform sampler2D lightmap;

uniform vec4 darkness_data;
uniform vec4 nv_color;
uniform vec4 nv_desaturation_params;
uniform vec4 nv_light_params;

float nv_intensity   = darkness_data.x;
float darkness       = darkness_data.y;
float timer          = darkness_data.z;
bool render_darkness = darkness_data.w > 0.0;

bool use_nightvision = nv_intensity > 0.0;

void main()
{
  vec2 uv = gl_TexCoord[0].xy;
  vec4 color = texture2D(gameview, uv);
  if (!render_darkness)
  {
    gl_FragColor = color;
    return;
  }
  
  vec4 light = texture2D(lightmap, uv);
  
  if (use_nightvision)
  {
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float lightLuminance = max(light.r, max(light.g, light.b));
    vec3 grayscale = vec3(luminance * nv_intensity); // * nv_color.a * nv_color.rgb;
    float lightIntensity = smoothstep(nv_desaturation_params.x, nv_desaturation_params.y, lightLuminance) * nv_desaturation_params.z + nv_desaturation_params.w; 
    
    if (lightLuminance > 0.0)
    {
      // Tint image by color of light divaded by light luminance to not make image darker
      color.rgb = color.rgb * ((light.rgb / lightLuminance) * 0.75 + 0.25);
    }
    
    color.rgb = mix(grayscale, color.rgb, lightIntensity);
    lightIntensity = smoothstep(nv_light_params.x, nv_light_params.y, lightLuminance) * nv_light_params.z + nv_light_params.w; 
    gl_FragColor = vec4(color.rgb * lightIntensity , color.a);   
  }
  else
  {
    color.rgb = color.rgb * light.rgb;
    gl_FragColor = vec4(color.rgb, color.a);  
  } 
}
