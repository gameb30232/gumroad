import React from "react";
import { usePage } from "@inertiajs/react";
import User, { type User as UserType } from "$app/components/Admin/Users/User";
import Product, { type Product as ProductType } from "$app/components/Admin/Products/Product";

type AdminProductProps = {
  user: UserType;
  product: ProductType
}

const AdminProductsShow = () => {
  const {
    user,
    product
  } = usePage().props as unknown as AdminProductProps;

  return (
    <div className="paragraphs">
      <Product
        key={product.id}
        product={product}
        is_affiliate_user={false}
      />
      <User user={user} is_affiliate_user={false} />
    </div>
  )
};

export default AdminProductsShow;
