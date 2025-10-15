import cx from "classnames";
import * as React from "react";

import { Icon } from "$app/components/Icons";

type AsideProps = {
  children: React.ReactNode;
  className?: string;
  ariaLabel?: string;
  onClose?: () => void;
  header?: React.ReactNode;
  fixed?: boolean;
};

export const Aside = ({ children, className, ariaLabel, onClose, header, fixed = true }: AsideProps) => {
  const classes = cx(
    // Base styles
    "overflow-auto bg-filled p-6 gap-4 flex flex-col",
    // Positioning
    fixed ? "fixed top-0 right-0 bottom-0 z-[var(--z-index-menubar)] w-full" : "relative",
    // Mobile behavior - hide on mobile when not fixed
    !fixed && "hidden lg:flex",
    // Responsive styles
    "lg:border-l lg:border-border lg:w-[40vw]",
    className,
  );

  return (
    <aside className={classes} aria-label={ariaLabel}>
      {header && (
        <header className="flex items-start justify-between gap-4">
          <div className="flex flex-1 items-start justify-between">{header}</div>
          {onClose && (
            <button type="button" onClick={onClose} aria-label="Close">
              <Icon name="x" />
            </button>
          )}
        </header>
      )}
      {children}
    </aside>
  );
};

type FixedAsideWrapperProps = {
  children: React.ReactNode;
  className?: string;
  showAside?: boolean;
};

export const FixedAsideWrapper = ({ children, className, showAside = true }: FixedAsideWrapperProps) => (
  <div className={cx("flex-1", showAside && "lg:grid lg:grid-cols-[1fr_30vw]", className)}>{children}</div>
);
