import { usePage } from "@inertiajs/react";
import React from "react";

import { default as ArchivedProductsPage, ArchivedProductsPageProps } from "$app/components/ArchivedProductsPage";

function Archived() {
  const props = usePage<ArchivedProductsPageProps>().props;

  return <ArchivedProductsPage {...props} />;
}

export default Archived;
