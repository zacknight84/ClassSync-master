const path = require("path");

/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      "@": path.resolve(__dirname),
    };
    return config;
  },

  experimental: {
    serverActions: {
      allowedOrigins: ["localhost:3000"],
    },
  },

  images: {
    remotePatterns: [],
  },

  productionBrowserSourceMaps: false,

  eslint: {
    ignoreDuringBuilds: false,
  },
  typescript: {
    ignoreBuildErrors: false,
  },
};

module.exports = nextConfig;