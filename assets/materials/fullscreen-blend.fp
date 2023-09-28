varying highp vec4 var_position;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex1;

void main()
{
    vec4 color1 = texture2D(tex0, var_texcoord0.xy);
    vec4 color2 = texture2D(tex1, var_texcoord0.xy);    
    gl_FragColor = vec4( (color1 + color2).rgb, 1.0);
    gl_FragDepth = 0.0;
}

