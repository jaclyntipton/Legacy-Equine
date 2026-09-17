"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";

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
};
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
}: {
  horses: Horse[];
  balance: number;
  notify: (message: string) => void;
  refresh: () => void;
}) {
  const [professions, setProfessions] = useState<Profession[]>([]),
    [ownerQa, setOwnerQa] = useState(false),
    [canEnroll, setCanEnroll] = useState(true),
    [directory, setDirectory] = useState<Directory[]>([]),
    [catalog, setCatalog] = useState<Catalog[]>([]),
    [modules, setModules] = useState<StudyModule[]>([]),
    [rates, setRates] = useState<Record<string, number>>({}),
    [offered, setOffered] = useState<Record<string, boolean>>({}),
    [filter, setFilter] = useState<string | null>(null),
    [directoryError, setDirectoryError] = useState(""),
    [search, setSearch] = useState(""),
    [sort, setSort] = useState("certification"),
    [questions, setQuestions] = useState<Question[]>([]),
    [testing, setTesting] = useState<Profession | null>(null),
    [answers, setAnswers] = useState<Record<string, number>>({}),
    [career, setCareer] = useState<{ id: string; qa: boolean } | null>(null),
    [careerTab, setCareerTab] = useState("overview"),
    [careerNotice, setCareerNotice] = useState(""),
    [qaLevel, setQaLevel] = useState(1),
    [qaStage, setQaStage] = useState("study"),
    [qaControlsOpen, setQaControlsOpen] = useState(false),
    [runNormal, setRunNormal] = useState(false),
    [request, setRequest] = useState<{
      providerId: string;
      serviceId: string;
    } | null>(null),
    [requestStep, setRequestStep] = useState<"service" | "horses" | "review">(
      "service",
    ),
    [selectedHorses, setSelectedHorses] = useState<string[]>([]),
    [batchPreview, setBatchPreview] = useState<BatchPreview | null>(null),
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
    ] = await Promise.all([
      supabase.rpc("get_profession_dashboard"),
      directoryRequest,
      supabase
        .from("service_catalog")
        .select(
          "id,profession_id,name,minimum_level,min_price,max_price,wellness_component,restoration_by_level,effect",
        )
        .eq("active", true),
      supabase
        .from("study_modules")
        .select("id,profession_id,level,title,summary,lessons")
        .eq("active", true)
        .order("sort_order"),
      offeringsRequest,
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
  }, [filter, notify]);
  useEffect(() => {
    const timer = setTimeout(() => void load(), 0);
    return () => clearTimeout(timer);
  }, [load]);
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
    setCareer({ id: p.id, qa: false });
    setCareerTab("study");
    setCareerNotice("");
  };
  const study = async (p: Profession) => {
    if (career?.qa && !runNormal) {
      setQaStage("test");
      setCareerTab("test");
      setCareerNotice(
        `Study Complete ✓ You’re ready for your ${["Basic", "Proficient", "Advanced", "Professional"][qaLevel - 1]} ${p.name} Certification Test.`,
      );
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
  };
  const openQaCareer = async (professionId: string, level: number) => {
    const { error } = await supabase.rpc("open_profession_qa_career", {
      target_profession: professionId,
      target_level: level,
    });
    if (error) return notify(error.message);
    setCareer({ id: professionId, qa: true });
    setQaLevel(level);
    setQaStage("study");
    setCareerTab("study");
    setRunNormal(false);
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
    setTesting(null);
    if (data.passed) {
      if (qa) {
        setQaStage(testedLevel === 4 ? "certified" : "services");
        setCareerTab(testedLevel === 4 ? "progression" : "services");
      } else {
        await load();
        refresh();
        setCareerTab(testedLevel === 4 ? "progression" : "services");
      }
      setCareerNotice(
        testedLevel === 4
          ? "Certification Test Passed ✓ Career Completed"
          : "Certification Test Passed ✓ Continue to your service requirement.",
      );
    } else
      notify(
        `Score: ${data.score}%. Study again and retry after the cooldown.`,
      );
  };
  const advanceCareer = async (p: Profession) => {
    if (career?.qa && !runNormal) {
      const next = Math.min(4, qaLevel + 1);
      setQaLevel(next);
      setQaStage("study");
      setCareerTab("study");
      setCareerNotice(
        `Ready to Advance ✓ ${["Basic", "Proficient", "Advanced", "Professional"][next - 1]} Study is now open.`,
      );
      return;
    }
    const { error } = await supabase.rpc("advance_profession_career", {
      target_profession: p.id,
    });
    if (error) return notify(error.message);
    await load();
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
    setRequestStep("service");
  };
  const loadEligibility = async () => {
    if (!request) return;
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
    if (!request || !batchPreview || !selectedHorses.length) return;
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
  return (
    <>
      {!career && (
        <>
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
          <div className="professiongrid">
            {professions.map((p) => (
              <article className="panel professioncard" key={p.id}>
                <p className="eyebrow">{p.level_name}</p>
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
                {p.level === 0 ? (
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
                      onClick={() => {
                        setCareer({ id: p.id, qa: false });
                        setCareerTab("overview");
                        setCareerNotice("");
                      }}
                    >
                      CONTINUE CAREER
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
          <section className="panel professionalmarket">
            <p className="eyebrow">PLAYER MARKET</p>
            <h2>Find a Professional</h2>
            <div className="professioncategories">
              {(
                [
                  ["farrier", "Farriers"],
                  ["veterinarian", "Veterinarians"],
                  ["trainer", "Trainers"],
                  ["massage", "Massage Therapists"],
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
                          <a href={`/stables/${provider.provider_id}`}>
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
          const level = career.qa ? qaLevel : (p.next_level ?? 4);
          const qa = career.qa && !runNormal;
          const normalStage =
            p.next_level === null
              ? "certified"
              : !p.next_level_advanced
                ? p.qualifying_credit >= p.required_services
                  ? "advancement"
                  : "services"
                : p.study_completed
                  ? "test"
                  : "study";
          const stage = qa ? qaStage : normalStage;
          const displayLevel =
            !career.qa && ["services", "advancement"].includes(stage)
              ? Math.max(1, p.level)
              : level;
          const levelName = names[displayLevel - 1];
          const advanceName = career.qa
            ? names[Math.min(3, qaLevel)]
            : names[level - 1];
          const step =
            stage === "study"
              ? 1
              : stage === "test"
                ? 2
                : stage === "services"
                  ? 3
                  : 4;
          const studyContent = modules.find(
            (item) => item.profession_id === p.id && item.level === level,
          );
          const allowed = (tab: string) =>
            tab === "overview" ||
            (tab === "study" && ["study", "test"].includes(stage)) ||
            (tab === "test" && stage === "test") ||
            (tab === "services" &&
              ["services", "advancement"].includes(stage)) ||
            (tab === "progression" &&
              ["advancement", "certified"].includes(stage));
          return (
            <main
              className="careerpage"
              aria-label={
                career.qa ? "Profession QA career" : "Career workspace"
              }
            >
              <section className="panel careerworkspace">
                <button
                  className="careerexit"
                  onClick={() => {
                    setCareer(null);
                    setCareerNotice("");
                  }}
                >
                  ← Exit Career
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
                              setRunNormal(event.target.checked)
                            }
                          />{" "}
                          Run as Normal Gameplay
                        </label>
                      </div>
                    )}
                  </div>
                )}
                {careerNotice && (
                  <div className="careernotice" role="status">
                    {careerNotice}
                  </div>
                )}
                <nav className="careertabs" aria-label="Career stages">
                  {["overview", "study", "test", "services", "progression"].map(
                    (tab) => (
                      <button
                        disabled={!allowed(tab)}
                        className={careerTab === tab ? "active" : ""}
                        key={tab}
                        onClick={() => setCareerTab(tab)}
                      >
                        {tab[0].toUpperCase() + tab.slice(1)}
                        {!allowed(tab) && tab !== "overview" ? " 🔒" : ""}
                      </button>
                    ),
                  )}
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
                      <p>
                        Pass the existing certification test to unlock the next
                        required stage.
                      </p>
                      <button
                        className="primary"
                        onClick={() => void openTest(p, level)}
                      >
                        OPEN CERTIFICATION TEST
                      </button>
                    </>
                  )}
                  {careerTab === "services" && (
                    <>
                      <h2>Service Requirement</h2>
                      <div className="serviceprogress">
                        <b>
                          Required Services:{" "}
                          {qa
                            ? `${qaStage === "services" ? 0 : p.required_services} / ${p.required_services}`
                            : `${p.qualifying_credit} / ${p.required_services}`}
                        </b>
                        <span
                          style={{
                            width: `${qa && qaStage !== "services" ? 100 : Math.min(100, p.required_services ? (p.qualifying_credit / p.required_services) * 100 : 100)}%`,
                          }}
                        />
                      </div>
                      <p>
                        Only legitimate completed services count toward normal
                        advancement.
                      </p>
                      {qa && (
                        <button
                          className="primary"
                          onClick={() => {
                            setQaStage("advancement");
                            setCareerTab("progression");
                            setCareerNotice("Ready to Advance ✓");
                          }}
                        >
                          CONTINUE TO ADVANCEMENT
                        </button>
                      )}
                      <button
                        onClick={() => {
                          setCareer(null);
                          setFilter(p.id);
                        }}
                      >
                        Open Professional Market
                      </button>
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
                          <button
                            className="primary"
                            onClick={() => void advanceCareer(p)}
                          >
                            ADVANCE TO {advanceName}
                          </button>
                        </>
                      )}
                    </>
                  )}
                </div>
              </section>
            </main>
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
              <b
                className={
                  requestStep === "horses" || requestStep === "review"
                    ? "active"
                    : ""
                }
              >
                Horses
              </b>
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
                <label>
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
                        {service.price.toLocaleString()} LED / horse
                      </option>
                    ))}
                  </select>
                </label>
                <div className="wizardactions">
                  <button onClick={() => setRequest(null)}>Cancel</button>
                  <button
                    className="primary"
                    disabled={!request.serviceId || !horses.length}
                    onClick={() => void loadEligibility()}
                  >
                    Select Horses
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
          </section>
        </div>
      )}
      {testing && (
        <div className="examoverlay" role="dialog" aria-modal="true">
          <section className="panel exam">
            <button className="examclose" onClick={() => setTesting(null)}>
              ×
            </button>
            <p className="eyebrow">{testing.name.toUpperCase()}</p>
            <h2>Certification Test</h2>
            {questions.map((q, index) => (
              <fieldset key={q.id}>
                <legend>
                  {index + 1}. {q.prompt}
                </legend>
                {q.choices.map((choice, i) => (
                  <label key={choice}>
                    <input
                      type="radio"
                      name={q.id}
                      checked={answers[q.id] === i}
                      onChange={() => setAnswers({ ...answers, [q.id]: i })}
                    />
                    {choice}
                  </label>
                ))}
              </fieldset>
            ))}
            <button
              className="primary"
              disabled={Object.keys(answers).length < questions.length}
              onClick={submit}
            >
              Submit Test
            </button>
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
