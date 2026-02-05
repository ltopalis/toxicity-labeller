"use strict";

const server_url = "https://toxicity-backend.onrender.com/";

localStorage.setItem("selectedLang", "null");

document
  .getElementById("submitBtn")
  .addEventListener("click", async function () {
    const form = document.getElementById("evaluationForm");
    const text_field = document.getElementById("text-to-eval");
    const formData = new FormData(form);

    const results = {
      toxicity: formData.get("toxicity"),
      bias_type: formData.get("bias_type"),
      target_type: formData.get("target_type"),
      text_id: text_field.getAttribute("text-id"),
    };

    if (!text_field.getAttribute("text-id")) return;

    try {
      const response = await fetch(server_url + "sendData", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(results),
      })
        .then((response) => response.json)
        .then((response) => console.log(response.ok));

      get_sample();
    } catch (err) {
      console.log(err);
    }
  });

async function get_sample() {
  try {
    const response = await fetch(server_url + "getSample", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ lang: localStorage.getItem("selectedLang") }),
    });

    if (!response.ok) throw new Error(`HTTP error ${response.status}`);

    const data = await response.json();

    const text_field = document.getElementById("text-to-eval");

    if (!data.text_id) {
      text_field.innerText =
        "Δεν υπάρχουν δεδομένα. Επίλεξε άλλη γλώσσα ή περίμενε μέχρι να προστεθούν";
      text_field.setAttribute("text-id", null);
    } else {
      text_field.innerText = data.text;
      text_field.setAttribute("text-id", data.text_id);
    }
  } catch (err) {
    console.log(err);
  }
}

function saveLanguage() {
  let selectedLang = document.querySelector(
    'input[name="langOption"]:checked',
  ).value;

  if (selectedLang === "all") selectedLang = "null";

  localStorage.setItem("selectedLang", selectedLang);

  get_sample();

  const modalElement = document.getElementById("modalWindow");
  const modal = bootstrap.Modal.getInstance(modalElement);
  modal.hide();

  if (document.activeElement) {
    document.activeElement.blur();
  }
}

function cancelLanguage() {
  let selectedLang = document.querySelector(
    'input[name="langOption"]:checked',
  ).value;

  let lang;
  if (localStorage.getItem("selectedLang") === "null") lang = "all";
  else lang = localStorage.getItem("selectedLang");

  document.getElementById(`lang_${selectedLang}`).checked = false;
  document.getElementById(`lang_${lang}`).checked = true;

  const modalElement = document.getElementById("modalWindow");
  const modal = bootstrap.Modal.getInstance(modalElement);
  modal.hide();

  if (document.activeElement) {
    document.activeElement.blur();
  }
}

const greek_lang = document.getElementById("lang_gr");
const german_lang = document.getElementById("lang_de");
const all_lang = document.getElementById("lang_all");

if (localStorage.getItem("selectedLang") === "null")
  all_lang.setAttribute("checked", true);
else if (localStorage.getItem("selectedLang") === "de")
  german_lang.setAttribute("checked", true);
else if (localStorage.getItem("selectedLang") === "gr")
  greek_lang.setAttribute("checked", true);

get_sample();
