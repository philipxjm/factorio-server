#version 120

uniform sampler2D material;
uniform sampler2D mask;
uniform sampler2D mask2;

void main()
{
  vec2 uv = gl_TexCoord[0].xy;
  vec4 colorMask = texture2D(mask2, gl_Color.rg) * texture2D(mask2, gl_Color.ba);
  vec4 colorMat = texture2D(material, uv);
  
  gl_FragColor = colorMat * colorMask.r;  
  return;
}
