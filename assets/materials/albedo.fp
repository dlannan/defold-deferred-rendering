varying highp vec4 var_position;
varying mediump vec3 var_normal;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;
uniform lowp sampler2D tex1;

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    vec4 color = texture2D(tex0, var_texcoord0.xy);
    vec4 merge = texture2D(tex1, var_texcoord0.xy);

    // Diffuse light calculations
    vec3 ambient_light = vec3(1.0);
    gl_FragColor = vec4( (color.rgb  * ambient_light + merge.rgb * ambient_light) * 0.5, 1.0);
}

