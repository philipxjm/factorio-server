#version 120

uniform sampler2D gameview; // "diffuse" texture
uniform sampler2D lightmap;

uniform vec4 darkness_data;
uniform vec4 nv_color;
uniform vec4 nv_desaturation_params;
uniform vec4 nv_light_params;
uniform vec4 ztw_params; // zoom-to-world parameters

float nv_intensity   = darkness_data.x;
float darkness       = darkness_data.y;
float timer          = darkness_data.z;
bool render_darkness = darkness_data.w > 0.0;

bool use_nightvision = nv_intensity > 0.0;

float hmix(float a, float b)
{
  // Not stolen at all
  return fract(sin(a * 12.9898 + b) * 43758.5453);
}

float hash3(float a, float b, float c)
{
  float ab = hmix(a, b);
  float ac = hmix(a, c);
  float bc = hmix(b, c);

  return hmix(ab, hmix(ac, bc));
}

vec3 getnoise3(vec2 p)
{
  return vec3(hash3(p.x, p.y, floor(timer / 3.)));
}

void main()
{
  vec2 uv = gl_TexCoord[0].xy;
  vec4 color = texture2D(gameview, uv);

  //gl_FragColor = color; return;

  vec3 noise = getnoise3(uv);
  color.rgb += noise.rgb * ztw_params.x + ztw_params.y;

  //float stripe = 0;
  //if (sin(timer * 0.02 + uv.y) > 0.99999)
  //  stripe = 0.1;
  //
  //color.rgb += stripe.xxx;

  //float vigAmt = 2.; //+.3*sin(tm + 5.*cos(tm*5.));
  //float vignette = (1.-vigAmt*(uv.y-.5)*(uv.y-.5))*(1.-vigAmt*(uv.x-.5)*(uv.x-.5));
  //color.rgb *= vignette;
  vec4 light = texture2D(lightmap, uv);

  if (use_nightvision)
  {
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float lightLuminance = max(light.r, max(light.g, light.b));
    vec3 grayscale = vec3(luminance * nv_intensity); // * nv_color.a * nv_color.rgb;
    float lightIntensity = smoothstep(nv_desaturation_params.x, nv_desaturation_params.y, lightLuminance) * nv_desaturation_params.z + nv_desaturation_params.w;

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
