import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [{ source: "/:path*", has: [{ type: "host", value: "www.legacyequines.com" }], destination: "https://legacyequines.com/:path*", permanent: true }];
  },
};

export default nextConfig;
