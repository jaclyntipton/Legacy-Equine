"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { ManageBusiness, MyBusinesses, ProfessionNav, PublicBusiness } from "@/app/profession-businesses";
import "./profession-qa-safety.css";

type Horse = {
  id: string;
  name: string;
  breed: string;
  birth_date: string;
  stats: Record<string, number>;
  last_trained_at: string | null;
};
type Profession = {
  id: string;
  name: string;
  description: string;
  enrollment_fee: number;
  exam_fee: number;
  enrolled: boolean;
  status_label: string;
  level: number;
  level_name: string;
  available: boolean;
  client_services: number;
  self_services: number;
  qualifying_credit: number;
  study_completed: boolean;
  required_services: number;
  next_level: number | null;
  next_level_advanced: boolean;
  career_completed: boolean;
  rates_configured: boolean;
  career_state: string;
  certified_levels: number[];
  requirement_overridden: boolean;
};
type Directory = {
  provider_id: string;
  stable_name: string;
  account_number: number;
  profession_id: string;
  profession_name: string;
  certification: string;
  certification_level: number;
  completed_services: number;
  service_id: string;
  service_name: string;
  price: number;
  owner_qa: boolean;
};
type Catalog = {
  id: string;
  profession_id: string;
  name: string;
  minimum_level: number;
  min_price: number;
  max_price: number;
  wellness_component: "health" | "hooves" | "recovery" | null;
  restoration_by_level: Record<string, number>;
  effect: Record<string, number>;
  tack_slot: string | null;
  tack_tier: string | null;
  stat_budget: number | null;
};
type CraftPreview = { provider_id:string;provider_name:string;service_id:string;service_name:string;slot:string;tier:string;budget:number;allocated:number;bonuses:Record<string,number>;custom_name:string|null;price:number;changed?:boolean };
type Wellness = {
  health: number;
  hooves: number;
  recovery: number;
  readiness: number;
  label: string;
};
type ServicePreview = {
  eligible: boolean;
  reason: string | null;
  next_eligible: string | null;
  horse_name: string;
  provider_name: string;
  service_name: string;
  profession_id: string;
  certification: string;
  price: number;
  owner_qa: boolean;
  current_state: Record<string, number | string>;
  expected_effect: string;
};
type BatchPreview = {
  horses: (ServicePreview & { horse_id: string })[];
  rate: number;
  eligible_count: number;
  selected_count: number;
  total: number;
};
type Question = { id: string; prompt: string; choices: string[] };
type CertificationCooldown = {
  active: boolean;
  available_at: string | null;
  retry_cooldown_minutes: number;
  failed_attempt_id: string | null;
  can_bypass: boolean;
};
type StudyModule = {
  id: string;
  profession_id: string;
  level: number;
  title: string;
  summary: string;
  lessons: string[];
};
const supabase = createClient();

export function ProfessionalCenter({
  horses,
  balance,
  notify,
  refresh,
  onTackDelivered,
}: {
  horses: Horse[];
  balance: number;
  notify: (message: string) => void;
  refresh: () => void;
  onTackDelivered?: () => void;
}) {
  const [professions, setProfessions] = useState<Profession[]>([]),
    [ownerQa, setOwnerQa] = useState(false),
    [canEnroll, setCanEnroll] = useState(true),
    [directory, setDirectory] = useState<Directory[]>([]),
    [catalog, setCatalog] = useState<Catalog[]>([]),
    [modules, setModules] = useState<StudyModule[]>([]),
    [requirements, setRequirements] = useState<Record<string, number>>({}),
    [rates, setRates] = useState<Record<string, number>>({}),
    [offered, setOffered] = useState<Record<string, boolean>>({}),
    [filter, setFilter] = useState<string | null>(null),
    [directoryError, setDirectoryError] = useState(""),
    [search, setSearch] = useState(""),
    [sort, setSort] = useState("certification"),
    [questions, setQuestions] = useState<Question[]>([]),
    [testing, setTesting] = useState<Profession | null>(null),
    [testResult, setTestResult] = useState<{
      passed: boolean;
      score: number;
    } | null>(null),
    [answers, setAnswers] = useState<Record<string, number>>({}),
    [career, setCareer] = useState<{ id: string; qa: boolean } | null>(null),
    [careerTab, setCareerTab] = useState("overview"),
    [careerNotice, setCareerNotice] = useState(""),
    [qaLevel, setQaLevel] = useState(1),
    [qaStage, setQaStage] = useState("study"),
    [qaControlsOpen, setQaControlsOpen] = useState(false),
    [runNormal, setRunNormal] = useState(false),
    [pendingLiveEnrollment, setPendingLiveEnrollment] = useState(false),
    [enrollingLive, setEnrollingLive] = useState(false),
    [overrideConfirming, setOverrideConfirming] = useState(false),
    [overrideBusy, setOverrideBusy] = useState(false),
    [certificationCooldown, setCertificationCooldown] =
      useState<CertificationCooldown | null>(null),
    [bypassingCooldown, setBypassingCooldown] = useState(false),
    [qaRateServices, setQaRateServices] = useState<Record<string, boolean>>({}),
    [qaServiceCredit, setQaServiceCredit] = useState(0),
    [request, setRequest] = useState<{
      providerId: string;
      serviceId: string;
    } | null>(null),
    [requestStep, setRequestStep] = useState<"service" | "horses" | "review">(
      "service",
    ),
    [selectedHorses, setSelectedHorses] = useState<string[]>([]),
    [batchPreview, setBatchPreview] = useState<BatchPreview | null>(null),
    [craftBonuses,setCraftBonuses]=useState<Record<string,number>>({}),
    [craftName,setCraftName]=useState(""),
    [craftPreview,setCraftPreview]=useState<CraftPreview|null>(null),
    [submitting, setSubmitting] = useState(false);
  const load = useCallback(async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const directoryRequest = filter
      ? supabase.rpc("get_service_directory", { target_profession: filter })
      : Promise.resolve({ data: [], error: null });
    const offeringsRequest = user
      ? supabase
          .from("player_service_offerings")
          .select("service_id,price,enabled")
          .eq("stable_id", user.id)
      : Promise.resolve({ data: [], error: null });
    const [
      { data: d, error: e },
      { data: listing, error: listingError },
      { data: services },
      { data: study },
      { data: offerings },
      { data: levelRequirements },
    ] = await Promise.all([
      supabase.rpc("get_profession_dashboard"),
      directoryRequest,
      supabase
        .from("service_catalog")
        .select(
          "id,profession_id,name,minimum_level,min_price,max_price,wellness_component,restoration_by_level,effect,tack_slot,tack_tier,stat_budget",
        )
        .eq("active", true),
      supabase
        .from("study_modules")
        .select("id,profession_id,level,title,summary,lessons")
        .eq("active", true)
        .order("sort_order"),
      offeringsRequest,
      supabase
        .from("profession_level_requirements")
        .select("profession_id,level,required_services"),
    ]);
    if (e) notify(e.message);
    else {
      setProfessions((d?.professions ?? []) as Profession[]);
      setOwnerQa(Boolean(d?.owner_qa_access));
      setCanEnroll(Boolean(d?.can_enroll));
    }
    setDirectory((listing ?? []) as Directory[]);
    setDirectoryError(listingError?.message ?? "");
    setCatalog((services ?? []) as Catalog[]);
    setModules((study ?? []) as StudyModule[]);
    const rows = (offerings ?? []) as {
      service_id: string;
      price: number;
      enabled: boolean;
    }[];
    setRates(
      Object.fromEntries(rows.map((row) => [row.service_id, row.price])),
    );
    setOffered(
      Object.fromEntries(rows.map((row) => [row.service_id, row.enabled])),
    );
    setRequirements(
      Object.fromEntries(
        (levelRequirements ?? []).map((row) => [
          `${row.profession_id}:${row.level}`,
          Number(row.required_services),
        ]),
      ),
    );
  }, [filter, notify]);
  useEffect(() => {
    const timer = setTimeout(() => void load(), 0);
    return () => clearTimeout(timer);
  }, [load]);
  useEffect(() => {
    const profession = new URLSearchParams(location.search).get("profession");
    if (profession) setFilter(profession);
  }, []);
  const professionRouteIds = useMemo(
    () => professions.map((profession) => profession.id).join("|"),
    [professions],
  );
  useEffect(() => {
    const syncCareerRoute = () => {
      const match = location.pathname.match(/^\/professions\/([^/]+)$/);
      if (!match) {
        setCareer(null);
        setRunNormal(false);
        return;
      }
      const profession = professions.find((item) => item.id === match[1]);
      if (!profession) return;
      const requestedQa = new URLSearchParams(location.search).get("qa") === "1";
      if ((requestedQa && !ownerQa) || (!requestedQa && !profession.enrolled)) {
        history.replaceState({ leProfessionCareer: true }, "", "/professions");
        setCareer(null);
        return;
      }
      setCareer({ id: profession.id, qa: requestedQa });
      setCareerTab("overview");
      setCareerNotice("");
      setTesting(null);
      setTestResult(null);
    };
    syncCareerRoute();
    addEventListener("popstate", syncCareerRoute);
    return () => removeEventListener("popstate", syncCareerRoute);
  }, [ownerQa, professionRouteIds]);
  const openCareerRoute = (professionId: string, qa: boolean) => {
    history.pushState(
      { leProfessionCareer: true },
      "",
      `/professions/${professionId}${qa ? "?qa=1" : ""}`,
    );
    setCareer({ id: professionId, qa });
    setCareerTab("overview");
    setCareerNotice("");
    setTesting(null);
    setTestResult(null);
    setPendingLiveEnrollment(false);
    setOverrideConfirming(false);
    setCertificationCooldown(null);
  };
  const backToProfessions = () => {
    history.pushState({ leProfessionCareer: true }, "", "/professions");
    setCareer(null);
    setRunNormal(false);
    setPendingLiveEnrollment(false);
    setOverrideConfirming(false);
    setCertificationCooldown(null);
    setCareerNotice("");
    setTesting(null);
    setTestResult(null);
  };
  const run = async (
    job: () => Promise<{ error: Error | null }>,
    ok: string,
  ) => {
    const { error } = await job();
    notify(error?.message ?? ok);
    if (!error) {
      await load();
      refresh();
    }
  };
  const enroll = async (p: Profession) => {
    const { error } = await supabase.rpc("enroll_profession", {
      target_profession: p.id,
    });
    if (error) return notify(error.message);
    await load();
    refresh();
    openCareerRoute(p.id, false);
    setCareerTab("study");
    setCareerNotice("");
  };
  const requestLiveMode = (p: Profession, enabled: boolean) => {
    if (!enabled) {
      setRunNormal(false);
      setPendingLiveEnrollment(false);
      setOverrideConfirming(false);
      setCareerTab("overview");
      setCareerNotice("");
      setTesting(null);
      setTestResult(null);
      return;
    }
    if (!p.enrolled) {
      setPendingLiveEnrollment(true);
      setRunNormal(false);
      return;
    }
    setPendingLiveEnrollment(false);
    setRunNormal(true);
    setCareerTab("overview");
    setCareerNotice("");
    setTesting(null);
    setTestResult(null);
    void loadCertificationCooldown(p.id, p.next_level ?? 4);
  };
  const loadCertificationCooldown = async (
    professionId: string,
    level: number,
  ) => {
    const { data, error } = await supabase.rpc(
      "get_profession_certification_cooldown",
      { target_profession: professionId, target_level: level },
    );
    if (error) return notify(error.message);
    setCertificationCooldown(data as CertificationCooldown);
  };
  const bypassCertificationCooldown = async (
    professionId: string,
    level: number,
  ) => {
    if (bypassingCooldown) return;
    setBypassingCooldown(true);
    const { error } = await supabase.rpc(
      "admin_bypass_profession_certification_cooldown",
      { target_profession: professionId, target_level: level },
    );
    setBypassingCooldown(false);
    if (error) return notify(error.message);
    await loadCertificationCooldown(professionId, level);
    setTesting(null);
    setTestResult(null);
    setCareerTab("test");
    setCareerNotice("Certification cooldown bypassed for QA. The failed attempt remains in history.");
  };
  const enrollFromQa = async (p: Profession) => {
    if (enrollingLive) return;
    setEnrollingLive(true);
    const { error } = await supabase.rpc("enroll_profession", {
      target_profession: p.id,
    });
    setEnrollingLive(false);
    if (error) return notify(error.message);
    await load();
    refresh();
    setPendingLiveEnrollment(false);
    setRunNormal(true);
    setCareerTab("study");
    setCareerNotice("Enrollment persisted ✓ Basic Study is ready.");
  };
  const markRequirementComplete = async (p: Profession) => {
    if (overrideBusy || p.level < 1) return;
    setOverrideBusy(true);
    const { error } = await supabase.rpc(
      "admin_mark_profession_requirement_complete",
      {
        target_profession: p.id,
        target_level: p.level,
        p_reason: "QA/testing",
      },
    );
    setOverrideBusy(false);
    if (error) return notify(error.message);
    await load();
    setOverrideConfirming(false);
    setCareerTab("progression");
    setCareerNotice(
      `Owner QA Progression Override ✓ Actual Services remain ${p.qualifying_credit}.`,
    );
  };
  const study = async (p: Profession) => {
    if (career?.qa && !runNormal) {
      setQaStage("test");
      setCareerTab("test");
      setCareerNotice(
        `Study Complete ✓ You’re ready for your ${["Basic", "Proficient", "Advanced", "Professional"][qaLevel - 1]} ${p.name} Certification Test.`,
      );
      await openTest(p, qaLevel);
      return;
    }
    const { error } = await supabase.rpc("complete_profession_study", {
      target_profession: p.id,
      target_level: p.next_level,
    });
    if (error) return notify(error.message);
    await load();
    refresh();
    setCareerTab("test");
    setCareerNotice(
      `Study Complete ✓ You’re ready for your ${["Basic", "Proficient", "Advanced", "Professional"][(p.next_level ?? 1) - 1]} ${p.name} Certification Test.`,
    );
    await openTest(p, p.next_level);
  };
  const openQaCareer = async (professionId: string, level: number) => {
    const { error } = await supabase.rpc("open_profession_qa_career", {
      target_profession: professionId,
      target_level: level,
    });
    if (error) return notify(error.message);
    openCareerRoute(professionId, true);
    setQaLevel(level);
    setQaStage("study");
    setCareerTab("study");
    setQaRateServices({});
    setQaServiceCredit(0);
  };
  const openTest = async (p: Profession, level = p.next_level) => {
    const qa = career?.qa && !runNormal;
    const { data, error } = await supabase.rpc(
      qa ? "get_profession_qa_questions" : "get_certification_questions",
      { target_profession: p.id, target_level: level },
    );
    if (error) return notify(error.message);
    setTesting({ ...p, next_level: level });
    setQuestions((data ?? []) as Question[]);
    setAnswers({});
    setTestResult(null);
  };
  const submit = async () => {
    if (!testing?.next_level) return;
    const qa = career?.qa && !runNormal;
    const testedLevel = testing.next_level;
    const { data, error } = await supabase.rpc(
      qa ? "grade_profession_qa_test" : "take_certification_test",
      {
        target_profession: testing.id,
        target_level: testedLevel,
        submitted_answers: answers,
      },
    );
    if (error) return notify(error.message);
    setTestResult({ passed: Boolean(data.passed), score: Number(data.score) });
    if (data.passed) {
      if (qa) {
        setQaStage("services");
        setQaRateServices({});
        setQaServiceCredit(0);
      } else {
        await load();
        refresh();
      }
      setCareerNotice(
        `Certification Test Passed ✓ Certificate Granted ✓ ${["Basic", "Proficient", "Advanced", "Professional"][testedLevel - 1]} ${testing.name} Certified`,
      );
    } else if (!qa) {
      await loadCertificationCooldown(testing.id, testedLevel);
    }
  };
  const advanceCareer = async (p: Profession) => {
    if (career?.qa && !runNormal) {
      if (qaLevel === 4) {
        setQaStage("certified");
        setCareerTab("progression");
        setCareerNotice("Career Completed ✓");
        return;
      }
      const next = Math.min(4, qaLevel + 1);
      setQaLevel(next);
      setQaStage("study");
      setCareerTab("study");
      setCareerNotice(
        `Ready to Advance ✓ ${["Basic", "Proficient", "Advanced", "Professional"][next - 1]} Study is now open.`,
      );
      return;
    }
    const { data, error } = await supabase.rpc("advance_profession_career", {
      target_profession: p.id,
    });
    if (error) return notify(error.message);
    await load();
    if (data?.completed) {
      setCareerTab("progression");
      setCareerNotice("Career Completed ✓");
      return;
    }
    setCareerTab("study");
    setCareerNotice(
      `Ready to Advance ✓ ${["Basic", "Proficient", "Advanced", "Professional"][(p.next_level ?? 1) - 1]} Study is now open.`,
    );
  };
  const providers = useMemo(() => {
    const grouped = new Map<
      string,
      { provider: Directory; services: Directory[] }
    >();
    for (const row of directory) {
      const current = grouped.get(row.provider_id);
      if (current) current.services.push(row);
      else grouped.set(row.provider_id, { provider: row, services: [row] });
    }
    const query = search.trim().toLowerCase();
    return [...grouped.values()]
      .filter(
        (item) =>
          !query ||
          `${item.provider.stable_name} ${item.services.map((s) => s.service_name).join(" ")}`
            .toLowerCase()
            .includes(query),
      )
      .sort((a, b) =>
        sort === "price"
          ? Math.min(...a.services.map((s) => s.price)) -
            Math.min(...b.services.map((s) => s.price))
          : sort === "name"
            ? a.provider.stable_name.localeCompare(b.provider.stable_name)
            : b.provider.certification_level - a.provider.certification_level,
      );
  }, [directory, search, sort]);
  const selectedProvider = request
    ? (providers.find(
        (item) => item.provider.provider_id === request.providerId,
      ) ?? null)
    : null;
  const selectedService =
    selectedProvider?.services.find(
      (service) => service.service_id === request?.serviceId,
    ) ?? null;
  const selectedCatalog=selectedService?catalog.find(item=>item.id===selectedService.service_id)??null:null;
  const isLeatherwork=selectedProvider?.provider.profession_id==="leatherworker";
  const startRequest = (providerId: string) => {
    const provider = providers.find(
      (item) => item.provider.provider_id === providerId,
    );
    setRequest({
      providerId,
      serviceId: provider?.services[0]?.service_id ?? "",
    });
    setSelectedHorses([]);
    setBatchPreview(null);
    setCraftPreview(null);setCraftBonuses({});setCraftName("");
    setRequestStep("service");
  };
  useEffect(() => {
    if (request || !providers.length) return;
    const params = new URLSearchParams(location.search);
    const providerId = params.get("provider");
    const serviceId = params.get("service");
    if (!providerId) return;
    const provider = providers.find(
      (item) => item.provider.provider_id === providerId,
    );
    if (!provider) return;
    const selected = provider.services.some(
      (service) => service.service_id === serviceId,
    )
      ? serviceId!
      : provider.services[0]?.service_id ?? "";
    setRequest({ providerId, serviceId: selected });
    setSelectedHorses([]);
    setBatchPreview(null);
    setRequestStep("service");
  }, [providers, request]);
  const loadEligibility = async () => {
    if (!request) return;
    if(isLeatherwork){
      const{data,error}=await supabase.rpc("preview_leatherwork_commission",{target_provider:request.providerId,target_service:request.serviceId,p_bonuses:craftBonuses,p_custom_name:craftName});
      if(error)return notify(error.message);setCraftPreview(data as CraftPreview);setRequestStep("review");return;
    }
    const { data, error } = await supabase.rpc(
      "preview_professional_services",
      {
        target_horses: horses.map((h) => h.id),
        target_provider: request.providerId,
        target_service: request.serviceId,
        owner_qa: selectedService?.owner_qa ?? false,
      },
    );
    if (error) return notify(error.message);
    setBatchPreview(data as BatchPreview);
    setSelectedHorses([]);
    setRequestStep("horses");
  };
  const reviewRequest = () => {
    if (selectedHorses.length) setRequestStep("review");
  };
  const confirmRequest = async () => {
    if(!request)return;
    if(isLeatherwork){
      if(!craftPreview)return;setSubmitting(true);
      const{data,error}=await supabase.rpc("purchase_leatherwork_commission",{target_provider:request.providerId,target_service:request.serviceId,p_bonuses:craftBonuses,p_custom_name:craftName,p_request_key:crypto.randomUUID(),expected_rate:craftPreview.price});
      setSubmitting(false);if(error)return notify(error.message);if(data?.changed){setCraftPreview(data as CraftPreview);return notify("The commission changed. Review the updated price before paying.");}
      notify(`${data.name} crafted and delivered to My Stable → Tack Room.`);setRequest(null);setCraftPreview(null);await load();refresh();onTackDelivered?.();return;
    }
    if (!batchPreview || !selectedHorses.length) return;
    setSubmitting(true);
    const { data, error } = await supabase.rpc(
      "purchase_professional_services",
      {
        target_horses: selectedHorses,
        target_provider: request.providerId,
        target_service: request.serviceId,
        p_request_key: crypto.randomUUID(),
        expected_rate: batchPreview.rate,
        owner_qa: selectedService?.owner_qa ?? false,
      },
    );
    setSubmitting(false);
    if (error) return notify(error.message);
    if (data?.changed) {
      setBatchPreview(data as BatchPreview);
      setSelectedHorses(
        (data.horses as BatchPreview["horses"])
          .filter((h) => h.eligible)
          .map((h) => h.horse_id),
      );
      return notify(
        "Eligibility changed. Review the updated horses and total before paying.",
      );
    }
    notify(
      `${data.horse_count} horse service${data.horse_count === 1 ? "" : "s"} completed with history recorded.`,
    );
    setRequest(null);
    setBatchPreview(null);
    await load();
    refresh();
  };
  const businessManage = typeof location!=="undefined"?location.pathname.match(/^\/professions\/businesses\/([^/]+)$/):null;
  const publicStorefront = typeof location!=="undefined"?location.pathname.match(/^\/professions\/storefront\/([^/]+)\/([^/]+)$/):null;
  if(typeof location!=="undefined"&&location.pathname==="/professions/businesses")return <MyBusinesses notify={notify}/>;
  if(businessManage)return <ManageBusiness professionId={businessManage[1]} notify={notify}/>;
  if(publicStorefront)return <PublicBusiness stableId={publicStorefront[1]} professionId={publicStorefront[2]} notify={notify}/>;
  return (
    <>
      {!career && (
        <>
          <ProfessionNav active={new URLSearchParams(location.search).get("section")==="market"?"market":"careers"}/>
          <header className="title">
            <div>
              <p className="eyebrow">LEGACY EQUINE GAME CERTIFICATIONS</p>
              <h1>Professional Services</h1>
              <p>
                Study, certify, build a lifetime record, and serve the horse
                community. These are in-game credentials—not real-world
                professional qualifications.
              </p>
            </div>
          </header>
          <div className="professiongrid" id="profession-careers">
            {professions.map((p) => (
              <article className="panel professioncard" key={p.id}>
                <p className="eyebrow">{p.status_label}</p>
                <h2>{p.name}</h2>
                <p>{p.description}</p>
                {ownerQa && (
                  <button
                    className="primary"
                    onClick={() =>
                      void openQaCareer(p.id, Math.max(1, p.next_level ?? 4))
                    }
                  >
                    OPEN QA CAREER
                  </button>
                )}
                {!p.enrolled ? (
                  <button
                    disabled={!canEnroll}
                    title={
                      !canEnroll
                        ? "Complete your current career through Professional first"
                        : ""
                    }
                    onClick={() => void enroll(p)}
                  >
                    ENROLL AS NORMAL PLAYER ·{" "}
                    {p.enrollment_fee.toLocaleString()} LED
                  </button>
                ) : (
                  <>
                    <div className="progressline">
                      <span>Lifetime record</span>
                      <b>{p.client_services + p.self_services} services</b>
                    </div>
                    <button
                      className={!ownerQa ? "primary" : ""}
                      onClick={() => openCareerRoute(p.id, false)}
                    >
                      {p.career_completed ? "VIEW CAREER" : "CONTINUE CAREER"}
                    </button>
                  </>
                )}
              </article>
            ))}
          </div>
          <section className="panel">
            <p className="eyebrow">YOUR SERVICES</p>
            <h2>Set Your Rates</h2>
            <p className="panelsub">
              Certification unlocks services and their permitted market range.
              Saved, enabled rates appear in the Professional Market.
            </p>
            <div className="servicelist">
              {catalog
                .filter(
                  (s) =>
                    (professions.find((p) => p.id === s.profession_id)?.level ??
                      0) >= s.minimum_level,
                )
                .map((s) => (
                  <article key={s.id}>
                    <span>
                      <b>{s.name}</b>
                      <small>
                        {s.min_price}–{s.max_price} LED
                      </small>
                    </span>
                    <input
                      aria-label={`${s.name} price`}
                      type="number"
                      min={s.min_price}
                      max={s.max_price}
                      value={rates[s.id] ?? s.min_price}
                      onChange={(e) =>
                        setRates({ ...rates, [s.id]: Number(e.target.value) })
                      }
                    />
                    <button
                      onClick={() =>
                        run(
                          async () => {
                            const next = !offered[s.id];
                            const { error } = await supabase.rpc(
                              "set_service_offering",
                              {
                                target_service: s.id,
                                new_price: rates[s.id] ?? s.min_price,
                                is_enabled: next,
                              },
                            );
                            return { error };
                          },
                          offered[s.id]
                            ? `${s.name} removed from the market.`
                            : `${s.name} is listed at ${rates[s.id] ?? s.min_price} LED.`,
                        )
                      }
                    >
                      {offered[s.id] ? "Disable" : "Offer Service"}
                    </button>
                  </article>
                ))}
            </div>
          </section>
          <section className="panel professionalmarket" id="professional-market">
            <p className="eyebrow">PLAYER MARKET</p>
            <h2>Find a Professional</h2>
            <div className="professioncategories">
              {(
                [
                  ["farrier", "Farriers"],
                  ["veterinarian", "Veterinarians"],
                  ["trainer", "Trainers"],
                  ["massage", "Massage Therapists"],
                  ["leatherworker", "Leatherworkers"],
                ] as const
              ).map(([id, label]) => (
                <button
                  className={filter === id ? "active" : ""}
                  key={id}
                  onClick={() => {
                    setFilter(id);
                    setSearch("");
                  }}
                >
                  {label}
                </button>
              ))}
            </div>
            {filter && (
              <>
                <div className="markettools">
                  <input
                    type="search"
                    aria-label="Search professional market"
                    placeholder="Search providers or services"
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                  />
                  <label>
                    Sort
                    <select
                      aria-label="Sort professional market"
                      value={sort}
                      onChange={(event) => setSort(event.target.value)}
                    >
                      <option value="certification">Certification</option>
                      <option value="price">Lowest rate</option>
                      <option value="name">Stable name</option>
                    </select>
                  </label>
                </div>
                {directoryError ? (
                  <p className="featurehint">
                    Professional Market unavailable: {directoryError}
                  </p>
                ) : (
                  <div className="providerlist">
                    {providers.map(({ provider, services }) => (
                      <article key={provider.provider_id}>
                        <span>
                          <a href={`/professions/storefront/${provider.provider_id}/${provider.profession_id}`}>
                            <b>
                              {provider.stable_name} #{provider.account_number}
                            </b>
                          </a>
                          <small>
                            {provider.certification} {provider.profession_name}{" "}
                            · {provider.completed_services} completed
                            {provider.owner_qa ? " · Owner QA" : ""}
                          </small>
                        </span>
                        <span>
                          <b>
                            {services.length} service
                            {services.length === 1 ? "" : "s"}
                          </b>
                          <small>
                            {services
                              .map(
                                (service) =>
                                  `${service.service_name} · ${service.price.toLocaleString()} LED`,
                              )
                              .join(" · ")}
                          </small>
                        </span>
                        <button
                          onClick={() => startRequest(provider.provider_id)}
                        >
                          Select Professional
                        </button>
                      </article>
                    ))}
                    {!providers.length && (
                      <p className="featurehint">
                        No providers currently available.
                      </p>
                    )}
                  </div>
                )}
              </>
            )}
          </section>
        </>
      )}
      {career &&
        (() => {
          const p = professions.find((item) => item.id === career.id);
          if (!p) return null;
          const names = ["Basic", "Proficient", "Advanced", "Professional"];
          const qa = career.qa && !runNormal;
          const level = qa ? qaLevel : (p.next_level ?? 4);
          const normalStage =
            {
              STUDY_REQUIRED: "study",
              TEST_AVAILABLE: "test",
              CERTIFIED: "rates",
              RATES_REQUIRED: "rates",
              SERVICE_EXPERIENCE_REQUIRED: "services",
              ADVANCEMENT_AVAILABLE: "advancement",
              NEXT_LEVEL_STUDY: "study",
              PROFESSIONAL_CERTIFIED: "certified",
            }[p.career_state] ?? "study";
          const stage = qa ? qaStage : normalStage;
          const displayLevel =
            !qa && ["rates", "services", "advancement"].includes(stage)
              ? Math.max(1, p.level)
              : level;
          const levelName = names[displayLevel - 1];
          const requiredServices =
            requirements[`${p.id}:${displayLevel}`] ?? p.required_services;
          const advanceName = qa
            ? names[Math.min(3, qaLevel)]
            : names[level - 1];
          const atProfessional = qa ? qaLevel >= 4 : p.level >= 4;
          const step =
            stage === "study"
              ? 1
              : stage === "test"
                ? 2
                : ["rates", "services"].includes(stage)
                  ? 3
                  : 4;
          const studyContent = modules.find(
            (item) => item.profession_id === p.id && item.level === level,
          );
          const rateLevel = qa ? qaLevel : p.level;
          const rateServices = catalog.filter(
            (service) =>
              service.profession_id === p.id &&
              service.minimum_level <= rateLevel,
          );
          const allRequiredRatesConfigured = qa
            ? rateServices.length > 0 &&
              rateServices.every((service) => qaRateServices[service.id])
            : p.rates_configured;
          const serviceCredit = qa
            ? qaStage === "advancement"
              ? requiredServices
              : qaServiceCredit
            : p.qualifying_credit;
          const requirementMet =
            serviceCredit >= requiredServices || (!qa && p.requirement_overridden);
          const allowed = (tab: string) =>
            tab === "overview" ||
            (tab === "rates" && (qa || p.level > 0)) ||
            (tab === "study" && ["study", "test"].includes(stage)) ||
            (tab === "test" && stage === "test") ||
            (tab === "services" &&
              allRequiredRatesConfigured &&
              ["services", "advancement"].includes(stage)) ||
            (tab === "progression" &&
              ["advancement", "certified"].includes(stage));
          return (
            <div
              className="careerpage"
              aria-label={
                career.qa ? "Profession QA career" : "Career workspace"
              }
            >
              <section className="panel careerworkspace">
                <button
                  className="careerexit"
                  onClick={backToProfessions}
                >
                  ← Back to Professions
                </button>
                <p className="eyebrow">
                  {career.qa ? "PROFESSION QA ACCESS" : "ACTIVE CAREER"}
                </p>
                <h1>{p.name} Career</h1>
                <p className="careerstep">
                  {levelName} •{" "}
                  {stage === "certified"
                    ? "Career Completed"
                    : `Step ${step} of 4`}
                </p>
                {career.qa && (
                  <div className="qapanel">
                    <button
                      className="qacollapse"
                      aria-expanded={qaControlsOpen}
                      onClick={() => setQaControlsOpen(!qaControlsOpen)}
                    >
                      QA Controls <span>{qaControlsOpen ? "▴" : "▾"}</span>
                    </button>
                    {qaControlsOpen && (
                      <div className="qacontrols">
                        <label>
                          Profession
                          <select
                            value={career.id}
                            onChange={(event) =>
                              void openQaCareer(event.target.value, qaLevel)
                            }
                          >
                            {professions.map((item) => (
                              <option key={item.id} value={item.id}>
                                {item.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label>
                          Level
                          <select
                            value={qaLevel}
                            onChange={(event) =>
                              void openQaCareer(
                                career.id,
                                Number(event.target.value),
                              )
                            }
                          >
                            {names.map((name, index) => (
                              <option key={name} value={index + 1}>
                                {name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label>
                          Stage
                          <select
                            value={qaStage}
                            onChange={(event) => {
                              const value = event.target.value;
                              setQaStage(value);
                              setTesting(null);
                              setTestResult(null);
                              setCareerTab(
                                value === "study"
                                  ? "study"
                                  : value === "test"
                                    ? "test"
                                  : value === "services"
                                      ? "services"
                                      : "progression",
                              );
                              setCareerNotice("");
                              setQaServiceCredit(
                                value === "advancement" ? requiredServices : 0,
                              );
                              if (
                                ["services", "advancement", "certified"].includes(
                                  value,
                                )
                              )
                                setQaRateServices(
                                  Object.fromEntries(
                                    rateServices.map((service) => [
                                      service.id,
                                      true,
                                    ]),
                                  ),
                                );
                            }}
                          >
                            <option value="study">Study</option>
                            <option value="test">Certification Test</option>
                            <option value="services">
                              Service Requirement
                            </option>
                            <option value="advancement">
                              Advancement Ready
                            </option>
                            <option value="certified">Certified</option>
                          </select>
                        </label>
                        <label className="availability">
                          <input
                            type="checkbox"
                            checked={runNormal}
                            onChange={(event) =>
                              requestLiveMode(p, event.target.checked)
                            }
                          />{" "}
                          Run as Normal Gameplay
                        </label>
                        {!runNormal && ["services", "advancement"].includes(qaStage) && (
                          <button
                            type="button"
                            onClick={() => {
                              setQaServiceCredit(requiredServices);
                              setQaStage("advancement");
                              setCareerNotice(
                                `${requiredServices} / ${requiredServices} — Simulated for QA ✓`,
                              );
                            }}
                          >
                            SIMULATE SERVICE REQUIREMENT COMPLETE
                          </button>
                        )}
                        {runNormal && p.enrolled && p.level > 0 && !p.requirement_overridden && (
                          <button
                            type="button"
                            onClick={() => setOverrideConfirming(true)}
                          >
                            ADMIN MARK REQUIREMENT COMPLETE
                          </button>
                        )}
                        {runNormal && p.requirement_overridden && (
                          <p>
                            Actual Services: {p.qualifying_credit} · Advancement
                            Requirement: Owner QA Override ✓
                          </p>
                        )}
                        {runNormal && certificationCooldown?.active && (
                          <div className="liveenrollmentprompt" role="status">
                            <b>Certification Cooldown Active</b>
                            <p>
                              Available again:{" "}
                              {certificationCooldown.available_at
                                ? new Date(
                                    certificationCooldown.available_at,
                                  ).toLocaleString()
                                : "after the configured retry period"}
                            </p>
                            {certificationCooldown.can_bypass && (
                              <button
                                type="button"
                                disabled={bypassingCooldown}
                                onClick={() =>
                                  void bypassCertificationCooldown(p.id, level)
                                }
                              >
                                {bypassingCooldown
                                  ? "BYPASSING…"
                                  : "BYPASS COOLDOWN FOR QA"}
                              </button>
                            )}
                          </div>
                        )}
                        {pendingLiveEnrollment && (
                          <div className="liveenrollmentprompt" role="alert">
                            <b>This career is not enrolled.</b>
                            <p>
                              Enroll for {p.enrollment_fee.toLocaleString()} LED to
                              continue in Live Gameplay.
                            </p>
                            <div>
                              <button
                                type="button"
                                onClick={() => setPendingLiveEnrollment(false)}
                              >
                                CANCEL
                              </button>
                              <button
                                type="button"
                                className="primary"
                                disabled={enrollingLive}
                                onClick={() => void enrollFromQa(p)}
                              >
                                {enrollingLive
                                  ? "ENROLLING…"
                                  : `ENROLL & CONTINUE — ${p.enrollment_fee.toLocaleString()} LED`}
                              </button>
                            </div>
                          </div>
                        )}
                        {overrideConfirming && (
                          <div className="liveenrollmentprompt" role="alertdialog">
                            <b>Confirm Owner QA progression override</b>
                            <p>
                              This will administratively satisfy the current
                              advancement requirement without creating fake service
                              records. Continue?
                            </p>
                            <div>
                              <button
                                type="button"
                                onClick={() => setOverrideConfirming(false)}
                              >
                                CANCEL
                              </button>
                              <button
                                type="button"
                                className="primary"
                                disabled={overrideBusy}
                                onClick={() => void markRequirementComplete(p)}
                              >
                                {overrideBusy ? "SAVING…" : "CONFIRM OWNER OVERRIDE"}
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )}
                {career.qa && (
                  <div
                    className={`careernotice qamodebanner ${runNormal ? "live" : "preview"}`}
                    role="status"
                  >
                    <b>{runNormal ? "LIVE GAMEPLAY" : "QA PREVIEW"}</b> — {runNormal
                      ? "progress, certifications, rates and services will be permanently saved."
                      : "changes will not affect permanent progression or market data."}
                  </div>
                )}
                {careerNotice && (
                  <div className="careernotice" role="status">
                    {careerNotice}
                  </div>
                )}
                <nav className="careertabs" aria-label="Career stages">
                  {[
                    "overview",
                    "study",
                    "test",
                    "services",
                    "rates",
                    "progression",
                  ].map((tab) => (
                      <button
                        disabled={!allowed(tab)}
                        className={careerTab === tab ? "active" : ""}
                        key={tab}
                        onClick={() => setCareerTab(tab)}
                      >
                        {tab[0].toUpperCase() + tab.slice(1)}
                        {!allowed(tab) && tab !== "overview" ? " 🔒" : ""}
                      </button>
                  ))}
                </nav>
                <div className="careercontent">
                  {careerTab === "overview" && (
                    <>
                      <h2>
                        {levelName} {p.name}
                      </h2>
                      <p>{p.description}</p>
                      <p>
                        Follow each unlocked step in order. Your progress is
                        saved whenever you exit.
                      </p>
                      <button
                        className="primary"
                        onClick={() =>
                          setCareerTab(
                            stage === "certified" ? "progression" : stage,
                          )
                        }
                      >
                        Continue Career
                      </button>
                    </>
                  )}
                  {careerTab === "study" && (
                    <>
                      <h2>{studyContent?.title ?? "Study module"}</h2>
                      <p>{studyContent?.summary}</p>
                      {studyContent?.lessons.map((lesson, index) => (
                        <section className="studylesson" key={index}>
                          <b>Section {index + 1}</b>
                          <p>{lesson}</p>
                        </section>
                      ))}
                      <button className="primary" onClick={() => void study(p)}>
                        CONTINUE TO TEST
                      </button>
                    </>
                  )}
                  {careerTab === "test" && (
                    <>
                      <h2>{levelName} Certification Test</h2>
                      <p>Study Complete ✓</p>
                      {!testing && (
                        <>
                          <p>
                            Pass the existing certification test to unlock the
                            next required stage.
                          </p>
                          <button
                            className="primary"
                            onClick={() => void openTest(p, level)}
                          >
                            OPEN CERTIFICATION TEST
                          </button>
                        </>
                      )}
                      {testing && !testResult && (
                        <div className="inlineexam">
                          {questions.map((q, index) => (
                            <fieldset key={q.id}>
                              <legend>
                                {index + 1}. {q.prompt}
                              </legend>
                              {q.choices.map((choice, choiceIndex) => (
                                <label
                                  className="examanswer"
                                  htmlFor={`profession-answer-${q.id}-${choiceIndex}`}
                                  key={choice}
                                >
                                  <input
                                    id={`profession-answer-${q.id}-${choiceIndex}`}
                                    type="radio"
                                    name={q.id}
                                    value={choiceIndex}
                                    checked={answers[q.id] === choiceIndex}
                                    onChange={() =>
                                      setAnswers((current) => ({
                                        ...current,
                                        [q.id]: choiceIndex,
                                      }))
                                    }
                                  />
                                  {choice}
                                </label>
                              ))}
                            </fieldset>
                          ))}
                          <button
                            className="primary"
                            disabled={
                              Object.keys(answers).length < questions.length
                            }
                            onClick={() => void submit()}
                          >
                            {career.qa && !runNormal
                              ? "Submit QA Test — Not Saved"
                              : "Submit Certification Test"}
                          </button>
                        </div>
                      )}
                      {testResult && (
                        <div className="testresult" role="status">
                          <h3>
                            {testResult.passed
                              ? "Test Passed ✓"
                              : "Test Not Passed"}
                          </h3>
                          <p>Score: {testResult.score}%</p>
                          {testResult.passed ? (
                            <button
                              className="primary"
                              onClick={() => {
                                setTesting(null);
                                setTestResult(null);
                                setCareerTab("rates");
                              }}
                            >
                              CONTINUE TO SET YOUR RATES
                            </button>
                          ) : (
                            <button
                              onClick={() => {
                                setTesting(null);
                                setTestResult(null);
                              }}
                            >
                              RETRY TEST
                            </button>
                          )}
                        </div>
                      )}
                    </>
                  )}
                  {careerTab === "services" && (
                    <>
                      <h2>Service Requirement</h2>
                      <p>✓ {levelName} {p.name} Certified</p>
                      <div className="serviceprogress">
                        <b>
                          Required Services:{" "}
                          {qa
                            ? `${serviceCredit} / ${requiredServices}`
                            : `${serviceCredit} / ${requiredServices}`}
                        </b>
                        <span
                          style={{
                            width: `${Math.min(100, requiredServices ? (serviceCredit / requiredServices) * 100 : 100)}%`,
                          }}
                        />
                      </div>
                      <p>
                        Only legitimate completed services count toward normal
                        advancement.
                      </p>
                      {!qa && p.requirement_overridden && (
                        <p>
                          Actual Services: {serviceCredit} · Advancement Requirement:
                          Owner QA Override ✓
                        </p>
                      )}
                      {!requirementMet && (
                        <p>
                          🔒 Advancement · Complete {requiredServices - serviceCredit}{" "}
                          additional {levelName} {p.name} client services to unlock {advanceName} certification training.
                        </p>
                      )}
                      {stage === "advancement" && requirementMet && (
                        <button
                          className="primary"
                          onClick={() => setCareerTab("progression")}
                        >
                          CONTINUE TO ADVANCEMENT
                        </button>
                      )}
                      <button
                        onClick={() => {
                          backToProfessions();
                          setFilter(p.id);
                        }}
                      >
                        Open Professional Market
                      </button>
                    </>
                  )}
                  {careerTab === "rates" && (
                    <>
                      <h2>Set Your Rates</h2>
                      <p>✓ {levelName} {p.name} Certified</p>
                      <p>
                        Rates are charged per {p.id==="leatherworker"?"crafted item":"horse"}. Enabled saved rates appear
                        in Find a Professional.
                      </p>
                      <div className="careerrates">
                        {rateServices.map((service) => (
                          <article key={service.id}>
                            <span>
                              <b>{service.name}</b>
                              <small>
                                {service.min_price}–{service.max_price} LED per {p.id==="leatherworker"?"item":"horse"}
                              </small>
                            </span>
                            <label>
                              Price per {p.id==="leatherworker"?"item":"horse"}
                              <input
                                aria-label={`${service.name} price per horse`}
                                type="number"
                                min={service.min_price}
                                max={service.max_price}
                                value={rates[service.id] ?? service.min_price}
                                onChange={(event) =>
                                  setRates({
                                    ...rates,
                                    [service.id]: Number(event.target.value),
                                  })
                                }
                              />
                            </label>
                            <button
                              className="primary"
                              onClick={() => {
                                const price =
                                  rates[service.id] ?? service.min_price;
                                if (career.qa && !runNormal) {
                                  if (
                                    price < service.min_price ||
                                    price > service.max_price
                                  )
                                    return notify(
                                      `Price must be between ${service.min_price} and ${service.max_price} LED.`,
                                    );
                                  const nextQaRates = {
                                    ...qaRateServices,
                                    [service.id]: true,
                                  };
                                  setQaRateServices(nextQaRates);
                                  notify(
                                    `QA rate validated at ${price} LED per horse · live market data unchanged.`,
                                  );
                                  if (
                                    rateServices.every(
                                      (item) => nextQaRates[item.id],
                                    )
                                  ) {
                                    setQaStage(
                                      atProfessional ? "certified" : "services",
                                    );
                                    setCareerTab(
                                      atProfessional
                                        ? "progression"
                                        : "services",
                                    );
                                  }
                                  return;
                                }
                                void (async () => {
                                  const { error } = await supabase.rpc(
                                    "set_service_offering",
                                    {
                                      target_service: service.id,
                                      new_price: price,
                                      is_enabled: true,
                                    },
                                  );
                                  if (error) return notify(error.message);
                                  const nextOffered = {
                                    ...offered,
                                    [service.id]: true,
                                  };
                                  setOffered(nextOffered);
                                  notify(
                                    `${service.name} saved at ${price} LED per horse.`,
                                  );
                                  await load();
                                  refresh();
                                  if (
                                    rateServices.every(
                                      (item) => nextOffered[item.id],
                                    )
                                  )
                                    setCareerTab(
                                      atProfessional
                                        ? "progression"
                                        : "services",
                                    );
                                })();
                              }}
                            >
                              {career.qa && !runNormal
                                ? "Save QA Rate — Not Saved"
                                : career.qa
                                  ? "Save Rate — Permanently Saved"
                                  : "SAVE & START ACCEPTING CLIENTS"}
                            </button>
                          </article>
                        ))}
                        {!rateServices.length && (
                          <p className="featurehint">
                            Certification is required before setting service
                            rates.
                          </p>
                        )}
                      </div>
                      {allRequiredRatesConfigured && (
                        <button
                          className="primary"
                          onClick={() => {
                            if (qa)
                              setQaStage(
                                atProfessional ? "certified" : "services",
                              );
                            setCareerTab(
                              atProfessional ? "progression" : "services",
                            );
                          }}
                        >
                          CONTINUE TO SERVICES
                        </button>
                      )}
                    </>
                  )}
                  {careerTab === "progression" && (
                    <>
                      {stage === "certified" ? (
                        <>
                          <h2>Career Completed ✓</h2>
                          <p>
                            You completed the Professional certification level
                            for {p.name}.
                          </p>
                        </>
                      ) : (
                        <>
                          <h2>Ready to Advance ✓</h2>
                          <p>
                            Your study, certification, and service requirements
                            are complete.
                          </p>
                          <p>
                            {levelName} → {atProfessional ? "Career Completed" : advanceName}
                          </p>
                          <button
                            className="primary"
                            onClick={() => void advanceCareer(p)}
                          >
                            {career.qa && !runNormal
                              ? atProfessional
                                ? "Complete QA Career — Not Saved"
                                : `Advance to ${advanceName} — Not Saved`
                              : career.qa
                                ? atProfessional
                                  ? "Complete Career — Permanently Saved"
                                  : `Advance to ${advanceName} — Permanently Saved`
                                : atProfessional
                                  ? "COMPLETE CAREER"
                                  : `ADVANCE TO ${advanceName}`}
                          </button>
                        </>
                      )}
                    </>
                  )}
                </div>
              </section>
            </div>
          );
        })()}
      {request && selectedProvider && (
        <div
          className="serviceoverlay"
          role="dialog"
          aria-modal="true"
          aria-label="Purchase professional service"
        >
          <section className="panel servicewizard">
            <button
              className="examclose"
              aria-label="Close service purchase"
              onClick={() => setRequest(null)}
            >
              ×
            </button>
            <p className="eyebrow">
              PURCHASE SERVICE ·{" "}
              {selectedProvider.provider.profession_name.toUpperCase()}
            </p>
            <div className="wizardsteps">
              <b className="active">Provider</b>
              <b className={requestStep !== "service" ? "active" : ""}>
                Service
              </b>
              {!isLeatherwork&&<b
                className={
                  requestStep === "horses" || requestStep === "review"
                    ? "active"
                    : ""
                }
              >
                Horses
              </b>}
              <b className={requestStep === "review" ? "active" : ""}>
                Review / Pay
              </b>
            </div>
            <h2>
              {selectedProvider.provider.stable_name} #
              {selectedProvider.provider.account_number}
            </h2>
            <p>
              {selectedProvider.provider.certification} certification
              {selectedProvider.provider.owner_qa ? " · Owner QA mode" : ""}
            </p>
            {requestStep === "service" && (
              <>
                {!isLeatherwork&&<label>
                  Service
                  <select
                    value={request.serviceId}
                    onChange={(event) =>
                      setRequest({ ...request, serviceId: event.target.value })
                    }
                  >
                    {selectedProvider.services.map((service) => (
                      <option
                        value={service.service_id}
                        key={service.service_id}
                      >
                        {service.service_name} ·{" "}
                        {service.price.toLocaleString()} LED / {isLeatherwork?"item":"horse"}
                      </option>
                    ))}
                  </select>
                </label>}
                {isLeatherwork&&<div className="productfilters">
                  <label>Tack Type<select value={selectedCatalog?.tack_slot??""} onChange={event=>{const service=selectedProvider.services.find(row=>{const configured=catalog.find(item=>item.id===row.service_id);return configured?.tack_slot===event.target.value&&configured?.tack_tier===selectedCatalog?.tack_tier});if(service)setRequest({...request,serviceId:service.service_id})}}>{[...new Set(selectedProvider.services.map(row=>catalog.find(item=>item.id===row.service_id)?.tack_slot).filter(Boolean))].map(slot=><option key={slot} value={slot!}>{slot==="saddle_pad"?"Saddle Pads":slot==="leg_protection"?"Leg Protection":`${slot![0].toUpperCase()}${slot!.slice(1)}s`}</option>)}</select></label>
                  <label>Tier<select value={selectedCatalog?.tack_tier??""} onChange={event=>{const service=selectedProvider.services.find(row=>{const configured=catalog.find(item=>item.id===row.service_id);return configured?.tack_tier===event.target.value&&configured?.tack_slot===selectedCatalog?.tack_slot});if(service)setRequest({...request,serviceId:service.service_id})}}>{["Entry","Quality","Elite","Legendary"].filter(tier=>selectedProvider.services.some(row=>catalog.find(item=>item.id===row.service_id)?.tack_tier===tier)).map(tier=><option key={tier}>{tier}</option>)}</select></label>
                  <p><b>{selectedService?.service_name}</b> · {selectedService?.price.toLocaleString()} LED / item</p>
                </div>}
                {isLeatherwork&&<>
                  <label>Optional custom item name<input maxLength={80} value={craftName} placeholder={`Custom ${selectedCatalog?.tack_tier??""} ${selectedService?.service_name?.replace(`${selectedCatalog?.tack_tier} `,"")??"Tack"}`} onChange={event=>setCraftName(event.target.value)}/></label>
                  <p><b>Allocate Effective Stats</b> · {Object.values(craftBonuses).reduce((sum,value)=>sum+value,0)} / {selectedCatalog?.stat_budget??0}</p>
                  <div className="statgrid">
                    {["Agility","Speed","Endurance","Temperament","Strength","Intelligence","Conformation"].map(stat=><label key={stat}>{stat}<input type="number" min={0} max={selectedCatalog?.stat_budget??0} value={craftBonuses[stat]??0} onChange={event=>setCraftBonuses({...craftBonuses,[stat]:Math.max(0,Number(event.target.value))})}/></label>)}
                  </div>
                  <small>Crafted tack changes Effective Stats only. It never changes permanent or breeding stats.</small>
                </>}
                <div className="wizardactions">
                  <button onClick={() => setRequest(null)}>Cancel</button>
                  <button
                    className="primary"
                    disabled={!request.serviceId || (isLeatherwork?Object.values(craftBonuses).reduce((sum,value)=>sum+value,0)<1||Object.values(craftBonuses).reduce((sum,value)=>sum+value,0)>(selectedCatalog?.stat_budget??0):!horses.length)}
                    onClick={() => void loadEligibility()}
                  >
                    {isLeatherwork?"Review Commission":"Select Horses"}
                  </button>
                </div>
              </>
            )}
            {requestStep === "horses" && batchPreview && (
              <>
                <div className="horsechoices">
                  <button
                    onClick={() =>
                      setSelectedHorses(
                        batchPreview.horses
                          .filter((item) => item.eligible)
                          .map((item) => item.horse_id),
                      )
                    }
                  >
                    SELECT ALL ELIGIBLE
                  </button>
                  {batchPreview.horses.map((item) => (
                    <label
                      className={!item.eligible ? "ineligible" : ""}
                      key={item.horse_id}
                    >
                      <input
                        type="checkbox"
                        disabled={!item.eligible}
                        checked={selectedHorses.includes(item.horse_id)}
                        onChange={(event) =>
                          setSelectedHorses(
                            event.target.checked
                              ? [...selectedHorses, item.horse_id]
                              : selectedHorses.filter(
                                  (id) => id !== item.horse_id,
                                ),
                          )
                        }
                      />
                      <span>
                        <b>{item.horse_name}</b>
                        <small>
                          {item.eligible
                            ? `Eligible · ${item.expected_effect}`
                            : item.reason}
                          {item.next_eligible
                            ? ` · Next: ${new Date(item.next_eligible).toLocaleString()}`
                            : ""}
                        </small>
                      </span>
                    </label>
                  ))}
                </div>
                <div className="wizardactions">
                  <button onClick={() => setRequestStep("service")}>
                    Back
                  </button>
                  <button
                    className="primary"
                    disabled={!selectedHorses.length}
                    onClick={reviewRequest}
                  >
                    Review {selectedHorses.length || ""}
                  </button>
                </div>
              </>
            )}
            {requestStep === "review" && batchPreview && (
              <>
                <div className="servicereview">
                  <p>
                    <span>Provider</span>
                    <b>{selectedProvider.provider.stable_name}</b>
                  </p>
                  <p>
                    <span>Service</span>
                    <b>{selectedService?.service_name}</b>
                  </p>
                  <p>
                    <span>Certification</span>
                    <b>{selectedProvider.provider.certification}</b>
                  </p>
                  <p>
                    <span>Horses selected</span>
                    <b>{selectedHorses.length}</b>
                  </p>
                  {selectedHorses.map((id) => {
                    const item = batchPreview.horses.find(
                      (h) => h.horse_id === id,
                    );
                    return (
                      <p key={id}>
                        <span>{item?.horse_name}</span>
                        <b>
                          {Object.entries(item?.current_state ?? {})
                            .map(([key, value]) => `${key}: ${value}`)
                            .join(" · ")}{" "}
                          · {item?.expected_effect}
                        </b>
                      </p>
                    );
                  })}
                  <p>
                    <span>Rate</span>
                    <b>{batchPreview.rate.toLocaleString()} LED / horse</b>
                  </p>
                  <p>
                    <span>Total</span>
                    <b>
                      {(
                        batchPreview.rate * selectedHorses.length
                      ).toLocaleString()}{" "}
                      LED
                    </b>
                  </p>
                  <p>
                    <span>Current balance</span>
                    <b>{balance.toLocaleString()} LED</b>
                  </p>
                  <p>
                    <span>Balance after</span>
                    <b>
                      {(
                        balance -
                        batchPreview.rate * selectedHorses.length
                      ).toLocaleString()}{" "}
                      LED
                    </b>
                  </p>
                </div>
                <div className="wizardactions">
                  <button onClick={() => setRequestStep("horses")}>Back</button>
                  <button
                    className="primary"
                    disabled={
                      submitting ||
                      (!selectedService?.owner_qa &&
                        balance < batchPreview.rate * selectedHorses.length)
                    }
                    onClick={() => void confirmRequest()}
                  >
                    {submitting
                      ? "Processing…"
                      : selectedService?.owner_qa
                        ? "RUN OWNER QA SERVICE"
                        : `PAY ${(batchPreview.rate * selectedHorses.length).toLocaleString()} LED`}
                  </button>
                </div>
              </>
            )}
            {requestStep==="review"&&isLeatherwork&&craftPreview&&<>
              <div className="servicereview">
                <p><span>Leatherworker</span><b>{selectedProvider.provider.stable_name} #{selectedProvider.provider.account_number}</b></p>
                <p><span>Item</span><b>{craftPreview.custom_name??`Custom ${craftPreview.service_name}`}</b></p>
                <p><span>Tier / slot</span><b>{craftPreview.tier} · {craftPreview.slot.replaceAll("_"," ")}</b></p>
                <p><span>Effective Stats</span><b>{Object.entries(craftPreview.bonuses).filter(([,value])=>value>0).map(([stat,value])=>`+${value} ${stat}`).join(" · ")}</b></p>
                <p><span>Price</span><b>{craftPreview.price.toLocaleString()} LED / item</b></p>
                <p><span>Current balance</span><b>{balance.toLocaleString()} LED</b></p>
                <p><span>Balance after</span><b>{(balance-craftPreview.price).toLocaleString()} LED</b></p>
              </div>
              <div className="wizardactions"><button onClick={()=>setRequestStep("service")}>Back</button><button className="primary" disabled={submitting||balance<craftPreview.price} onClick={()=>void confirmRequest()}>{submitting?"Processing…":`PAY ${craftPreview.price.toLocaleString()} LED`}</button></div>
            </>}
          </section>
        </div>
      )}
    </>
  );
}

type ServiceRecord = {
  completed_at: string;
  profession_name: string;
  service_name: string;
  provider_name: string;
  provider_account: number;
  certification: string;
  quality: string;
  effect: Record<string, number>;
  effect_expires_at: string | null;
  self_service: boolean;
};
export function HorseCare({
  horseId,
  section,
}: {
  horseId: string;
  section: "farrier" | "health";
}) {
  const [history, setHistory] = useState<ServiceRecord[]>([]),
    [care, setCare] = useState<Wellness | null>(null);
  useEffect(() => {
    void Promise.all([
      supabase.rpc("get_horse_service_history", { target_horse: horseId }),
      supabase.rpc("get_horse_wellness", { p_horse: horseId }),
    ]).then(([records, wellness]) => {
      setHistory((records.data ?? []) as ServiceRecord[]);
      setCare((wellness.data ?? null) as Wellness | null);
    });
  }, [horseId]);
  const shown = history.filter((r) =>
    section === "farrier"
      ? r.profession_name === "Farrier"
      : r.profession_name !== "Farrier",
  );
  return (
    <section className="panel">
      <p className="eyebrow">PERMANENT HORSE RECORD</p>
      <h2>
        {section === "farrier" ? "Farrier" : "Health, Training & Recovery"}
      </h2>
      {care && (
        <div className="wellnesssummary">
          {(
            [
              ["Health", care.health],
              ["Hooves", care.hooves],
              ["Recovery", care.recovery],
              ["Readiness", care.readiness],
            ] as const
          ).map(([label, value]) => (
            <article key={label}>
              <span>{label}</span>
              <b>{Math.round(value)}/100</b>
              <div>
                <i style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
              </div>
            </article>
          ))}
        </div>
      )}
      <p className="panelsub">
        Wellness is separate from inherited stats and permanent development.
        Professional care restores wellness; service history is permanent.
      </p>
      {shown.map((r) => (
        <div
          className="servicehistory"
          key={`${r.completed_at}-${r.service_name}`}
        >
          <span>
            <b>{r.service_name}</b>
            <small>
              {new Date(r.completed_at).toLocaleDateString()} ·{" "}
              {r.provider_name} #{r.provider_account}
            </small>
          </span>
          <span>
            <b>{r.quality}</b>
            <small>
              {r.certification} {r.profession_name}
              {r.self_service ? " · Self-service" : ""}
            </small>
          </span>
          <span>
            {Object.entries(r.effect).map(([stat, value]) => (
              <small key={stat}>
                {stat} +{value}
                {r.effect_expires_at
                  ? ` until ${new Date(r.effect_expires_at).toLocaleDateString()}`
                  : " permanent development"}
              </small>
            ))}
          </span>
        </div>
      ))}
      {!shown.length && (
        <p className="featurehint">
          No {section === "farrier" ? "farrier" : "health or recovery"} services
          recorded yet. Schedule one in Professional Services.
        </p>
      )}
    </section>
  );
}
