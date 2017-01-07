#pragma blendmode_add

uniform sampler2D tex0;

void main() {
    vec4 color_tex = texture2D(tex0, gl_TexCoord[0].xy);
    vec3 color = gl_Color.xyz * color_tex.xyz;

    gl_FragColor = vec4(color, color_tex.a * gl_Color.a);
}
