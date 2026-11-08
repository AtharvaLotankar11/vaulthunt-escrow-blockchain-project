import { DemoRunner } from "@/components/demo/DemoRunner";
import { PageHeader } from "@/components/ui/PageHeader";

export const metadata = { title: "Demo mode: VaultHunt" };

export default function DemoPage() {
  return (
    <section className="page-x py-12">
      <PageHeader chip="Demo mode" title="Watch the whole story" />
      <DemoRunner />
    </section>
  );
}
