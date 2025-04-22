//
//  ContentView.swift
//  shift
//
//  Created by Christian Cattaneo on 4/21/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Use black background
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer() // Pushes content below status bar slightly

                // Logo
                Image("shiftlogo") // Use the correct image set name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150) // Adjust size as needed
                    .padding(.bottom, 20)

                // Title
                Text("Shift")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)

                // Subtitle
                Text("See Singles Where You're At")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 40) // Add padding below subtitle

                Spacer() // Pushes buttons to the bottom

                // Sign Up Button
                Button(action: {
                    // TODO: Implement Sign Up action
                    print("Sign Up Tapped")
                }) {
                    Text("SIGN UP")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue) // Using system blue, adjust as needed
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)

                // Already Have Account Button
                Button(action: {
                    // TODO: Implement Login action
                    print("Already Have Account Tapped")
                }) {
                    Text("ALREADY HAVE AN ACCOUNT?")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 10) // Add spacing above this button

                Spacer().frame(height: 40) // Add padding at the bottom

            }
            .padding(.top) // Add padding to the top of the VStack
        }
    }
}

#Preview {
    ContentView()
}
