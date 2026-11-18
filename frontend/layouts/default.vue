<template>
    <div>
        <header>
            <NuxtLink to="/">My Blog</NuxtLink>
            <NuxtLink to="/articles/new"><a-button type="primary">New Article</a-button></NuxtLink>
        </header>

        <slot />

        <footer>
            <p>© 2024 My Blog</p>
        </footer>
    </div>
</template>
