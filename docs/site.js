const REPO = "Smartoptimize/aivaos-releases";
const $ = (id) => document.getElementById(id);

const bytes = (n) => (n ? `${(n / (1024 * 1024)).toFixed(0)} MB` : "");

document.querySelectorAll("[data-scroll]").forEach((el) => {
  el.addEventListener("click", (event) => {
    const target = document.querySelector(el.getAttribute("href"));
    if (!target) return;
    event.preventDefault();
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
});

const detectNote = () => {
  const ua = navigator.userAgent || "";
  const platform = navigator.platform || "";
  if (/Windows|Win32|Win64/i.test(ua) || /Win/i.test(platform)) {
    return "We detected Windows on this computer.";
  }
  if (/Mac/i.test(platform) || /Macintosh/i.test(ua)) {
    return "AivaOS desktop installs on Windows only right now. On a Mac? Use the Linux server install below on a VPS instead.";
  }
  if (/Linux/i.test(platform) && !/Android/i.test(ua)) {
    return "Running Linux on this machine? Use the server install below instead of the Windows download.";
  }
  return "";
};

$("detectNote").textContent = detectNote();

const showError = () => {
  $("loadingMsg")?.classList.add("hidden");
  $("downloadErr")?.classList.remove("hidden");
};

const renderRelease = (release) => {
  const assets = release.assets || [];
  const exe = assets.find((a) => /^AIVAOS-.*-win-x64\.exe$/i.test(a.name));
  const checksums = assets.find((a) => /^SHA256SUMS$/i.test(a.name));

  document.querySelectorAll("[data-version]").forEach((el) => {
    el.textContent = release.tag_name || "unreleased";
  });

  if (!exe) {
    showError();
    return;
  }

  $("primaryDownload").href = exe.browser_download_url;
  $("primaryDownload").removeAttribute("data-scroll");

  $("loadingMsg")?.classList.add("hidden");
  const card = $("downloadCard");
  card.classList.remove("hidden");
  card.innerHTML = `
    <div class="download-row">
      <div class="meta">
        <b>${exe.name}</b>
        <span>${bytes(exe.size)} · ${release.tag_name}</span>
      </div>
      <a class="btn btn-accent" href="${exe.browser_download_url}">Download</a>
    </div>
    ${checksums ? `<p class="checksum-link">Verify the download: <a href="${checksums.browser_download_url}">SHA256SUMS</a></p>` : ""}
  `;
};

fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
  .then((res) => {
    if (!res.ok) throw new Error("release-fetch-failed");
    return res.json();
  })
  .then(renderRelease)
  .catch(showError);
