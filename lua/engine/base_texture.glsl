@ctype mat4 hmm_mat4

@vs vs
layout(binding=0, std140) uniform vs_params {
    mat4 mvp;
    vec4 base_color_factor;
};

layout(location=0) in vec3 position;
layout(location=1) in vec2 texcoord;
layout(location=2) in vec2 normal;

out vec2 uv;
out vec4 base_color_out;

void main() {
    uv = texcoord;
    base_color_out = base_color_factor;
    gl_Position = mvp * vec4(position, 1.0);
}
@end

@fs fs
layout(location=0) in vec2 uv;
layout(location=1) in vec4 base_color_out;

layout(binding=0) uniform texture2D base_color_tex;
layout(binding=0) uniform sampler base_color_smp;

out vec4 frag_color;

void main() {
    vec4 tex_color = texture(sampler2D(base_color_tex, base_color_smp), uv);
    frag_color = tex_color * base_color_out;
}
@end

@program base_texture vs fs