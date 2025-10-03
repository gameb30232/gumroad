import React from "react";
import { Head, usePage } from "@inertiajs/react";

import AdminNav from "$app/components/Admin/Nav";
import AdminSearchPopover from "$app/components/Admin/SearchPopover";

import useRouteLoading from "$app/components/useRouteLoading";
import LoadingSkeleton from "$app/components/LoadingSkeleton";
import { classNames } from "$app/utils/classNames";
import { CurrentUser } from "$app/types/user";

type CardType = {
  id: string;
  name: string;
};

type PageProps = {
  title: string;
  current_user: CurrentUser;
  card_types: CardType[];
};

const Admin = ({ children }: { children: React.ReactNode }) => {
  const { title, current_user, card_types } = usePage().props as unknown as PageProps;
  const isRouteLoading = useRouteLoading();
  return (
    <div id="inertia-shell" className="flex h-screen flex-col lg:flex-row">
      <Head title={title} />

      <AdminNav title={title} current_user={current_user} />
      <main className="flex-1 flex flex-col h-screen overflow-y-auto">
        <header className="flex items-center justify-between border-b border-border p-4 md:p-8">
          <h1>{title}</h1>
          <div className="actions">
            <AdminSearchPopover card_types={card_types} />
          </div>
        </header>
        {isRouteLoading ? <LoadingSkeleton /> : null}
        <div className={classNames("p-4 md:p-8", { hidden: isRouteLoading })}>{children}</div>
      </main>
    </div>
  );
}

export default Admin;
