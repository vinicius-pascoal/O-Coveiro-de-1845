#pragma shader sky
// Céu noturno procedural: gradiente que se funde à névoa no horizonte,
// estrelas cintilantes, lua com halo e nuvens finas iluminadas pela lua.
// Cores em linear. O WorldController muda as cores a cada noite/final.

#pragma param vec3 zenithColor color "Cor do alto do céu"
#pragma param vec3 horizonColor color "Cor do horizonte (igual à névoa)"
#pragma param vec3 moonColor color "Cor da lua e do halo"
#pragma param vec3 moonDirection "Direção da lua no céu (aponta para a lua)"
#pragma param float moonSize = 0.035 [0.005, 0.2] "Raio angular do disco da lua"
#pragma param float starAmount = 1.0 [0, 3] "Quantidade e brilho das estrelas"
#pragma param float cloudAmount = 0.55 [0, 1] "Cobertura de nuvens"
#pragma param float horizonHeight = 0.28 [0.02, 1] "Altura da faixa de névoa no horizonte"

#pragma stage fragment

float skyHash(vec3 p){
    p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float skyNoise(vec3 p){
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(skyHash(i + vec3(0, 0, 0)), skyHash(i + vec3(1, 0, 0)), f.x),
                   mix(skyHash(i + vec3(0, 1, 0)), skyHash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(skyHash(i + vec3(0, 0, 1)), skyHash(i + vec3(1, 0, 1)), f.x),
                   mix(skyHash(i + vec3(0, 1, 1)), skyHash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float skyFbm(vec3 p){
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++){
        v += a * skyNoise(p);
        p = p * 2.03 + vec3(1.7, 9.2, 3.1);
        a *= 0.5;
    }
    return v;
}

float stars(vec3 dir, float scale, float threshold, float t){
    vec3 p = dir * scale;
    vec3 cell = floor(p);
    float h = skyHash(cell);
    if (h < threshold) return 0.0;
    vec3 center = cell + 0.5 + (vec3(skyHash(cell + 3.1), skyHash(cell + 7.7), skyHash(cell + 1.3)) - 0.5) * 0.6;
    float d = length(p - center);
    float twinkle = 0.65 + 0.35 * sin(t * (1.5 + h * 4.0) + h * 40.0);
    return smoothstep(0.22, 0.0, d) * twinkle * (h - threshold) / (1.0 - threshold);
}

vec4 getColor(FragmentContext context, vec4 color){
    vec3 dir = normalize(context.direction);
    float t = Engine.time;
    float up = dir.y;

    // gradiente: horizonte (névoa) -> zênite
    float h = clamp(up / params.horizonHeight, 0.0, 1.0);
    vec3 sky = mix(params.horizonColor, params.zenithColor, pow(h, 0.65));

    // lua: disco, borda suave e halo largo
    vec3 moonDir = normalize(params.moonDirection + vec3(0.0, 1e-4, 0.0));
    float cosAngle = dot(dir, moonDir);
    float angle = acos(clamp(cosAngle, -1.0, 1.0));
    float disc = smoothstep(params.moonSize, params.moonSize * 0.85, angle);
    float craters = 0.82 + 0.18 * skyFbm(dir * 90.0);
    float halo = exp(-angle * 9.0) * 0.35 + exp(-angle * 2.5) * 0.08;
    sky += params.moonColor * halo;

    // estrelas só acima do horizonte, apagadas perto da lua
    float starMask = smoothstep(0.02, 0.25, up) * (1.0 - smoothstep(0.35, 0.0, angle));
    float s = stars(dir, 160.0, 0.965, t) + stars(dir, 420.0, 0.985, t * 1.3) * 0.6;
    sky += vec3(0.85, 0.9, 1.0) * s * params.starAmount * starMask;

    // nuvens finas que andam devagar, iluminadas pela lua
    vec2 cloudUV = dir.xz / (max(up, 0.0) + 0.18);
    float c = skyFbm(vec3(cloudUV * 1.6 + vec2(t * 0.012, t * 0.004), t * 0.01));
    float cloud = smoothstep(1.0 - params.cloudAmount, 1.05 - params.cloudAmount * 0.5, c) * smoothstep(-0.02, 0.18, up);
    vec3 cloudColor = mix(params.zenithColor * 1.6, params.moonColor * 0.55, exp(-angle * 1.8) * 0.8 + 0.15);

    // disco da lua por cima de tudo, coberto em parte pelas nuvens
    vec3 moon = params.moonColor * 2.2 * craters;
    sky = mix(sky, moon, disc * (1.0 - cloud * 0.6));
    sky = mix(sky, cloudColor, cloud * 0.75);

    // abaixo do horizonte: cor da névoa
    sky = mix(params.horizonColor, sky, smoothstep(-0.05, 0.02, up));

    return vec4(sky, 1.0);
}
