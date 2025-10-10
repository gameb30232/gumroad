import { usePage } from "@inertiajs/react";
import React from "react";

import { default as CollabsPage, CollabsPageProps } from "$app/components/CollabsPage";

function Collabs() {
  const props = usePage<CollabsPageProps>().props;

  return <CollabsPage {...props} />;
}

export default Collabs;
