// ═══════════════════════════════════════════════════════════════
// mycelium_pulse.gdshader — Canvas item shader for mycelium effects
// Pulsing glow, connection lines, absorption bursts
// ═══════════════════════════════════════════════════════════════
shader_type canvas_item;

uniform float pulse_time : hint_range(0.0, 1.0) = 0.0;
uniform vec4 pulse_color : source_color = vec4(0.25, 0.75, 0.35, 1.0);
uniform float pulse_radius : hint_range(0.0, 1.0) = 0.5;
uniform int effect_type : hint_range(0, 3) = 0; // 0=grow, 1=absorb, 2=trade, 3=connection

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);

	if (effect_type == 0) {
		// Grow pulse: expanding ring
		float ring = abs(dist - pulse_radius) * 10.0;
		float alpha = (1.0 - pulse_time) * (1.0 - smoothstep(0.0, 0.3, ring));
		COLOR = vec4(pulse_color.rgb, pulse_color.a * alpha * 0.4);
	} else if (effect_type == 1) {
		// Absorb: expanding filled circle
		float alpha = (1.0 - pulse_time) * (1.0 - smoothstep(pulse_radius, pulse_radius + 0.05, dist));
		COLOR = vec4(pulse_color.rgb, pulse_color.a * alpha * 0.6);
	} else if (effect_type == 2) {
		// Trade: large expanding ring
		float ring = abs(dist - pulse_radius * 1.5) * 8.0;
		float alpha = (1.0 - pulse_time) * (1.0 - smoothstep(0.0, 0.4, ring));
		COLOR = vec4(pulse_color.rgb, pulse_color.a * alpha * 0.5);
	} else {
		// Connection: steady glow with slight pulse
		float glow = exp(-dist * 6.0) * (0.5 + 0.5 * sin(pulse_time * 3.14159));
		COLOR = vec4(pulse_color.rgb, pulse_color.a * glow * 0.3);
	}
}
