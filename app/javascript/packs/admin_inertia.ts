import { createInertiaApp } from "@inertiajs/react";
import React, { createElement } from "react";
import { createRoot } from "react-dom/client";

import AdminAppWrapper from "../inertia/admin_app_wrapper";
import Layout from "../layouts/Admin";

const AdminLayout = ((page: React.ReactNode) => React.createElement(Layout, { children: page }));

const resolvePageComponent = async (name: string) => {
  try {
    const page = await import(`../pages/${name}.tsx`);
    page.default.layout = AdminLayout;
    return page.default;
  } catch {
    try {
      const page = await import(`../pages/${name}.jsx`);
      page.default.layout = AdminLayout;
      return page.default;
    } catch {
      throw new Error(`Admin page component not found: ${name}`);
    }
  }
}

createInertiaApp({
  progress: false,
  resolve: (name: string) => resolvePageComponent(name),
  setup({ el, App, props }) {
    if (!el) return;

    const global = props.initialPage.props as any;

    const root = createRoot(el);
    root.render(createElement(AdminAppWrapper, { global, children: createElement(App, props) }));
  },
  title: (title: string) => title ? `${title} - Admin` : "Admin",
});
