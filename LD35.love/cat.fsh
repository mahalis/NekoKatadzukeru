extern vec3 color1;
extern vec3 color2;

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec4 t = Texel(texture, textureCoordinates);
	vec4 c = vec4(color1 * t.r + color2 * t.b + vec3(0.95, 0.56, 0.87) /* nose pink */ * t.g, t.a);
	return c * color;
}