import * as React from "react";

import { useDomains } from "$app/components/DomainSettings";
import { PageHeader } from "$app/components/ui/PageHeader";

import background from "$assets/images/auth/background.png";

export const Layout = ({
  children,
  header,
  headerActions,
}: {
  children: React.ReactNode;
  header: React.ReactNode;
  headerActions?: React.ReactNode;
}) => {
  const { rootDomain, scheme } = useDomains();

  return (
    <div className="flex flex-1">
      <div className="squished flex-1">
        <PageHeader
          title={<a href={`${scheme}://${rootDomain}`} className="logo-full" aria-label="Gumroad" />}
          actions={headerActions}
          className="p-8 sm:p-16"
        >
          {header}
        </PageHeader>
        <div className="p-8 sm:p-16">{children}</div>
      </div>
      <div className="w-[40vw] hidden lg:block border-l relative">
        <img src={background} className="size-full max-h-full object-cover absolute inset-0" />
      </div>
    </div>
  );
};
