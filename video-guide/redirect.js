const fallbackUrl = "https://youtu.be/QwxG2S_PCMQ";

fetch(`./config.json?v=${Date.now()}`, {cache: "no-store"})
    .then((response) => {
        if (!response.ok) throw new Error(`Video guide config returned ${response.status}`);
        return response.json();
    })
    .then((config) => {
        const url = typeof config.url === "string" && /^https?:\/\//.test(config.url)
            ? config.url
            : fallbackUrl;
        window.location.replace(url);
    })
    .catch(() => window.location.replace(fallbackUrl));
