varying highp vec4 var_position;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex1;

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    vec4 colorbg = texture2D(tex0, var_texcoord0.xy);
    vec4 color = texture2D(tex1, var_texcoord0.xy);    
    if(color.r == 0.0 && color.g == 0.0 && color.b == 0.0)
    {
        color = colorbg;
    }
    
    // Diffuse light calculations
    gl_FragColor = vec4(color.rgb,1.0);
}

