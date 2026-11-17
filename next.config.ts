import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      { source: "/store/supplies/:path*", destination: "/store/foundation-horses", permanent: false },
      { source: "/:path*", has: [{ type: "host", value: "www.legacyequines.com" }], destination: "https://legacyequines.com/:path*", permanent: true },
    ];
  },
};

export default nextConfig;
