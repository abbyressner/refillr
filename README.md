# refillr

## table of contents

1. [overview](#overview)  
2. [product spec](#product-spec)  
3. [wireframes](#wireframes)  
4. [schema](#schema)


## overview

### description

refillr is an iOS app that helps users with chronic health conditions manage their monthly medication and supplement refill process. instead of daily reminders, the app provides a structured, checklist-based interface during refill sessions to prevent mistakes, reduce overwhelm, and track historical usage. it’s especially useful for users managing multiple medications across different times of day (morning, afternoon, evening).

### app evaluation

- **category:** health & wellness / productivity  
- **mobile:** yes — native ios/android, possibly a web companion  
- **story:** users track and refill their meds/supplements once a month using customized checklists and historical logs  
- **market:** individuals with chronic health conditions, caregivers, elderly populations, and supplement users  
- **habit:** monthly or biweekly usage during refill sessions  
- **scope:** mvp focuses on checklist-based refilling, logging past use, and storing trusted/favorite products with reorder links


## product spec

### 1. user stories

**required must-have stories**

- user can create an account and log in  
- user can opt to “just let me in” without creating an account (data stored locally)  
- user can add a med/supplement with name, dosage, time of day, count, and optional reorder link  
- user can organize items into morning, afternoon, and evening categories  
- user can check off each item as they refill their organizer  
- app confirms completed items and asks follow-up like “did you finish refilling <item>?”  
- user can see past refill sessions (date, what was checked off)  
- user can add notes or effects experienced from a supplement  
- user can rate supplements on a 5-star personal usefulness scale  
- user can create a favorites list with product details for easy reorder  

**optional nice-to-have stories**

- user receives a notification after a short delay if they didn’t complete refilling  
- user can export or share their supplement/med list  
- app supports reorder via amazon affiliate links  
- user can duplicate a previous refill session to speed up the next one  
- user can set temporary breaks or stop/start dates for an item  
- auto-suggest from known supplements/meds API when adding a new item  


### 2. screen archetypes

- [ ] **login / auth screen**  
  - user can log in or sign up  
  - user can tap “just let me in” for temporary session  

- [x] **home / refill checklist screen**  
  - user sees three sections: morning, afternoon, evening  
  - user taps checkboxes as they refill each item  
  - user gets confirmation prompts on completion (still working on this)

- [ ] **add / edit item screen**
  - user inputs name, dosage, time of day, count, link  
  - user optionally logs notes or effects  

- [ ] **past sessions / history screen**  
  - user sees historical logs of what they’ve refilled and when  

- [x] **favorites / reorder screen** (underdeveloped, but it's there)
  - user sees trusted products with quick links to buy again  
  - user can edit or remove favorite items  


### 3. navigation

**tab navigation** (tab to screen)

- refill  
- history  
- items/favorites  

**flow navigation** (screen to screen)

- [ ] login screen  
  - → home screen (refill)  
  - → account setup  

- [x] refill screen  
  - → add/edit item  
  - → session complete dialog  

- [ ] history screen  
  - → view details of a past refill  

- [x] favorites screen  
  - → reorder product (via link)  

## video demo

<div>
    <a href="https://www.loom.com/share/eadf3d801eec4180b16cd301d531cb63">
      <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/eadf3d801eec4180b16cd301d531cb63-5ef8874852526a01-full-play.gif">
    </a>
  </div>
