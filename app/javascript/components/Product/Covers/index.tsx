import * as React from "react";

import { AssetPreview } from "$app/parsers/product";

import { Icon } from "$app/components/Icons";
import { useElementDimensions } from "$app/components/useElementDimensions";
import { useOnChange } from "$app/components/useOnChange";
import { useScrollableCarousel } from "$app/components/useScrollableCarousel";
import { classNames } from "$app/utils/classNames";

import { Embed } from "./Embed";
import { Image } from "./Image";
import { Video } from "./Video";

export const DEFAULT_IMAGE_WIDTH = 1005;

export const Covers = ({
  covers,
  activeCoverId,
  setActiveCoverId,
  closeButton,
  className,
  isThumbnail,
}: {
  covers: AssetPreview[];
  activeCoverId: string | null;
  setActiveCoverId: (id: string | null) => void;
  closeButton?: React.ReactNode;
  className?: string;
  isThumbnail?: boolean;
}) => {
  useOnChange(() => {
    if (!covers.some((cover) => cover.id === activeCoverId)) setActiveCoverId(covers[0]?.id ?? null);
  }, [covers]);

  let activeCoverIndex = covers.findIndex((cover) => cover.id === activeCoverId);
  if (activeCoverIndex === -1) activeCoverIndex = 0;
  const activeCover = covers[activeCoverIndex];
  const aspectRatio =
    !isThumbnail && covers[0]?.native_height && covers[0]?.native_width
      ? covers[0].native_width / covers[0].native_height
      : undefined;
  const prevCover = covers[activeCoverIndex - 1];
  const nextCover = covers[activeCoverIndex + 1];

  const { itemsRef, handleScroll } = useScrollableCarousel(activeCoverIndex, (index) =>
    setActiveCoverId(covers[index]?.id ?? null),
  );

  return (
    <figure className={classNames("relative group col-[1/-1]", className)} aria-label="Product preview">
      {closeButton}
      {prevCover ? <PreviewArrow direction="previous" onClick={() => setActiveCoverId(prevCover.id)} /> : null}
      {nextCover ? <PreviewArrow direction="next" onClick={() => setActiveCoverId(nextCover.id)} /> : null}
      <div
        className="flex overflow-x-scroll overflow-y-hidden snap-x snap-mandatory [scrollbar-width:none] [&::-webkit-scrollbar]:hidden items-center h-full"
        ref={itemsRef}
        style={{
          aspectRatio,
        }}
        onScroll={handleScroll}
      >
        {covers.map((cover) => (
          <CoverItem cover={cover} key={cover.id} />
        ))}
      </div>
      {covers.length > 1 && activeCover?.type !== "oembed" && activeCover?.type !== "video" ? (
        <div role="tablist" aria-label="Select a cover" className="absolute bottom-0 w-full flex justify-center gap-2 p-3 flex-wrap">
          {covers.map((cover, i) => (
            <div
              key={i}
              role="tab"
              aria-label={`Show cover ${i + 1}`}
              aria-selected={i === activeCoverIndex}
              aria-controls={cover.id}
              onClick={(e) => {
                e.preventDefault();
                setActiveCoverId(cover.id);
              }}
              className={classNames(
                "block border border-current p-2 rounded-full bg-background",
                i === activeCoverIndex && "bg-current"
              )}
            />
          ))}
        </div>
      ) : null}
    </figure>
  );
};

const PreviewArrow = ({ direction, onClick }: { direction: "previous" | "next"; onClick: () => void }) => {
  const iconName = direction === "previous" ? "arrow-left" : "arrow-right";
  const positionClass = direction === "previous" ? "left-0" : "right-0";

  return (
    <button
      className={classNames(
        "p-3 hidden absolute top-1/2 -translate-y-1/2 items-center justify-center z-1",
        "group-hover:flex",
        positionClass
      )}
      onClick={(e) => {
        e.preventDefault();
        onClick();
      }}
      aria-label={direction === "previous" ? "Show previous cover" : "Show next cover"}
    >
      <span className="block p-4 bg-background border border-border rounded-full relative">
        <Icon name={iconName} className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" />
      </span>
    </button>
  );
};

const CoverItem = ({ cover }: { cover: AssetPreview }) => {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const dimensions = useElementDimensions(containerRef);
  const width = dimensions?.width;

  let coverComponent: React.ReactNode;
  if (cover.type === "unsplash") {
    coverComponent = <img src={cover.url} />;
  } else if (
    width &&
    cover.width !== null &&
    cover.height !== null &&
    cover.native_width !== null &&
    cover.native_height !== null
  ) {
    const ratio = width / cover.native_width;
    const dimensions =
      ratio >= 1
        ? {
            width: cover.width,
            height: cover.height,
          }
        : {
            width: cover.native_width * ratio,
            height: cover.native_height * ratio,
          };
    if (cover.type === "image") {
      coverComponent = <Image cover={cover} dimensions={dimensions} />;
    } else if (cover.type === "oembed") {
      coverComponent = <Embed cover={cover} dimensions={dimensions} />;
    } else {
      coverComponent = <Video cover={cover} dimensions={dimensions} />;
    }
  }

  return (
    <div key={cover.id} ref={containerRef} role="tabpanel" id={cover.id} className="snap-start flex flex-[1_0_100%] min-h-[1px] justify-center !p-0 !mt-0 !border-0">
      {coverComponent}
    </div>
  );
};
