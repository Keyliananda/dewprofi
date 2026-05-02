<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_receive_current_user(): void
    {
        $response = $this->frontend()->postJson('/api/register', [
            'name' => 'Dew Profi',
            'email' => 'dew@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('user.email', 'dew@example.com')
            ->assertJsonMissingPath('user.password');

        $this->assertAuthenticated();
        $this->assertDatabaseHas('users', [
            'email' => 'dew@example.com',
        ]);
    }

    public function test_user_can_login_fetch_profile_and_logout(): void
    {
        $user = User::factory()->create([
            'email' => 'dew@example.com',
            'password' => Hash::make('password123'),
        ]);

        $this->frontend()->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'password123',
        ])
            ->assertOk()
            ->assertJsonPath('user.email', $user->email);

        $this->frontend()->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('user.email', $user->email);

        $this->frontend()->postJson('/api/logout')
            ->assertOk()
            ->assertJsonPath('message', 'Abgemeldet.');

        $this->frontend()->getJson('/api/me')->assertUnauthorized();
    }

    public function test_me_requires_an_authenticated_session(): void
    {
        $this->frontend()->getJson('/api/me')->assertUnauthorized();
    }

    public function test_invalid_login_is_rejected(): void
    {
        User::factory()->create([
            'email' => 'dew@example.com',
            'password' => Hash::make('password123'),
        ]);

        $this->frontend()->postJson('/api/login', [
            'email' => 'dew@example.com',
            'password' => 'wrong-password',
        ])->assertUnprocessable();
    }

    private function frontend(): static
    {
        return $this->withHeader('Origin', 'http://localhost:5173');
    }
}
